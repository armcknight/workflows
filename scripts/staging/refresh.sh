#!/usr/bin/env bash
# Re-signs a PR's staging install link without rebuilding, and comments it.
#
# Re-signs run RUN_ID's build with `ota-publish --mode refresh`, or the PR's
# newest build when RUN_ID is empty, and comments the new link on the PR. The
# PR's earlier install links, refresh notices and `/refresh-staging` and
# `/build-staging` commands are hidden as outdated.
#
# When there is no build to re-sign, it comments the reason on the PR and exits
# 1. The one exception: the newest "Staging build ready" comment is at least
# RETENTION_DAYS old, REBUILD_EXPIRED is `true`, and the PR is open and not from
# a fork. Then it comments that a new build is being made and exits 10, so the
# caller can start one.
#
#   S3_BUCKET         Required.
#   AWS_REGION        Required.
#   PROJECT           The repo's name, which namespaces its builds. Required.
#   PR_NUMBER         Required.
#   RUN_ID            The build to re-sign. Default: the PR's newest.
#   LINK_TTL_SECONDS  Lifetime of the install link. Default: 43200.
#   RETENTION_DAYS    Age at which the bucket deletes a build. Default: 30.
#   REBUILD_EXPIRED   `true` or `false` (the default).
#   RUN_URL           This run, for the rebuild notice. Default: the GitHub
#                     Actions run GITHUB_RUN_ID of GH_REPO.
#   GH_TOKEN          A token with pull-requests: write.
#   GH_REPO           owner/name.
#
# Needs AWS credentials that can read the bucket and that last as long as the
# link, and ota-publish (armcknight/tools) on PATH.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

: "${S3_BUCKET:?Set S3_BUCKET.}" "${AWS_REGION:?Set AWS_REGION.}" "${PROJECT:?Set PROJECT.}"
: "${PR_NUMBER:?Set PR_NUMBER.}" "${GH_REPO:?Set GH_REPO to owner/name.}"
RUN_ID="${RUN_ID:-}"
LINK_TTL_SECONDS="${LINK_TTL_SECONDS:-43200}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
REBUILD_EXPIRED="${REBUILD_EXPIRED:-false}"
RUN_URL="${RUN_URL:-${GITHUB_SERVER_URL:-https://github.com}/$GH_REPO/actions/runs/${GITHUB_RUN_ID:-}}"

here="$(dirname "$0")"
prefix="s3://$S3_BUCKET/$PROJECT/pr-$PR_NUMBER/"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# The PR's comments that a refresh makes stale, this run's own
# `/refresh-staging` command included. Read before posting anything, so a
# comment this run posts is never among them.
"$here/../pr/stale-comments.sh" collect "$PR_NUMBER" "$tmp/stale-comments.jsonl"

# Explains on the PR why there is no link, then fails.
fail_missing_build() {
  error "$1"
  printf '%s\n\nStaging builds are probably deleted %s days after they are made, by the lifecycle rule on the staging bucket. A refresh only re-signs a build that exists, so it cannot make a new one.\n\nTo get a new staging build, comment `/build-staging` on this PR. Do not close and reopen the PR: closing it deletes all of its staging builds.\n' \
    "$1" "$RETENTION_DAYS" > "$tmp/comment.md"
  gh pr comment "$PR_NUMBER" --body-file "$tmp/comment.md" || true
  # The commands are answered, and this notice replaces earlier ones. Keep the
  # old links visible: with an explicit RUN_ID, another build of the PR can
  # still be there.
  "$here/../pr/stale-comments.sh" hide "$tmp/stale-comments.jsonl" command notice
  exit 1
}

# A run's build is there only while its metadata.json is. ota-publish uploads
# it with the IPA, once, so the lifecycle rule deletes them together; a refresh
# uploads manifest.plist and install.html again, so the run's prefix can
# outlive the build. `aws s3 ls` exits non-zero when nothing has the key.
build_exists() {
  aws s3 ls "${prefix}run-$1/metadata.json" > /dev/null
}

if [ -n "$RUN_ID" ]; then
  if ! build_exists "$RUN_ID"; then
    fail_missing_build "The staging build for run $RUN_ID of PR #$PR_NUMBER is not available."
  fi
else
  RUN_ID=$(aws s3 ls "$prefix" \
    | awk '{print $2}' | grep '^run-' | sed 's#run-##; s#/##' | sort -V | tail -1 || true)
  # Every older run is older still, so when the newest build is gone, all of
  # them are.
  if [ -n "$RUN_ID" ] && ! build_exists "$RUN_ID"; then
    RUN_ID=""
  fi
fi

if [ -z "$RUN_ID" ]; then
  # The newest "Staging build ready" comment dates the newest build. A refresh
  # does not upload the IPA or metadata.json again, so it does not reset the
  # build's age.
  last_staged=$(jq -rs 'map(select(.kind == "staged")) | last | .createdAt // empty' "$tmp/stale-comments.jsonl")
  age_days=-1
  if [ -n "$last_staged" ]; then
    age_days=$(jq -rn --arg t "$last_staged" '(now - ($t | fromdateiso8601)) / 86400 | floor')
  fi

  if [ "$age_days" -ge "$RETENTION_DAYS" ] && [ "$REBUILD_EXPIRED" = "true" ]; then
    # Only rebuild an open PR from a branch in this repo: closing a PR deletes
    # its builds on purpose, and a fork's code must not run with this repo's
    # secrets.
    state=$("$here/pr-state.sh")
    if [ "$state" = "OPEN" ]; then
      printf 'The staging build for this PR expired: it was made %s days ago, and the staging bucket deletes builds after %s days.\n\nMaking a new staging build now ([run](%s)). Its install link will be posted here when the Stage job finishes.\n' \
        "$age_days" "$RETENTION_DAYS" "$RUN_URL" > "$tmp/comment.md"
      gh pr comment "$PR_NUMBER" --body-file "$tmp/comment.md"
      "$here/../pr/stale-comments.sh" hide "$tmp/stale-comments.jsonl" staged refreshed notice command
      exit 10
    fi
    echo "PR #$PR_NUMBER is $state; not rebuilding."
  fi

  if [ "$age_days" -ge 0 ]; then
    fail_missing_build "The staging build for PR #$PR_NUMBER is not available. The newest one was made $age_days days ago."
  fi
  fail_missing_build "No staging build was found for PR #$PR_NUMBER."
fi

result=$(ota-publish \
  --mode refresh \
  --bucket "$S3_BUCKET" \
  --region "$AWS_REGION" \
  --project "$PROJECT" \
  --pr "$PR_NUMBER" \
  --run-id "$RUN_ID" \
  --ttl "$LINK_TTL_SECONDS")
landing=$(printf '%s' "$result" | jq -r '.landingUrl')
expires=$(printf '%s' "$result" | jq -r '.expiresAt')
build_expires=$("$here/build-expiry.sh" "$S3_BUCKET" "$PROJECT" "$PR_NUMBER" "$RUN_ID")

printf 'Refreshed staging install link (run `%s`).\n\nOpen on your iPhone/iPad in **Safari** on a registered device, then tap Install:\n\n[📲 Install staging build](%s)\n\n_Link expires %s. Comment `/refresh-staging` again for another._\n' \
  "$RUN_ID" "$landing" "$expires" > "$tmp/comment.md"
if [ -n "$build_expires" ]; then
  printf '\n_The build itself is deleted %s, by the lifecycle rule on the staging bucket._\n' \
    "$build_expires" >> "$tmp/comment.md"
fi

gh pr comment "$PR_NUMBER" --body-file "$tmp/comment.md"
"$here/../pr/stale-comments.sh" hide "$tmp/stale-comments.jsonl" staged refreshed notice command
