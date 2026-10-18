#!/usr/bin/env bash
# Publishes a staging build and comments its install link on the PR.
#
# Uploads IPA with `ota-publish --mode initial` under
# s3://<S3_BUCKET>/<PROJECT>/pr-<PR_NUMBER>/run-<RUN_ID>/, then comments the
# presigned install link on the PR, with the time the bucket's lifecycle rule
# deletes the build. The PR's earlier install links, refresh notices and
# `/refresh-staging` and `/build-staging` commands are hidden as outdated (not
# its UI screenshots, which the ui-screenshots job replaces itself).
#
#   IPA               The IPA to publish. Required.
#   S3_BUCKET         Required.
#   AWS_REGION        Required.
#   PROJECT           The repo's name, which namespaces its builds. Required.
#   PR_NUMBER         Required.
#   RUN_ID            Names the build. Required.
#   LINK_TTL_SECONDS  Lifetime of the install link. Default: 43200.
#   RUN_URL           The run that made the build, for the comment. Default:
#                     the GitHub Actions run RUN_ID of GH_REPO.
#   GH_TOKEN          A token with pull-requests: write.
#   GH_REPO           owner/name.
#
# Run it in the checkout the IPA was built from: the comment names its HEAD.
# Needs AWS credentials that can write the bucket and that last as long as the
# link, and ota-publish (armcknight/tools), build-expiry and stale-comments
# (.github/actions/) on PATH.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

: "${IPA:?Set IPA.}" "${S3_BUCKET:?Set S3_BUCKET.}" "${AWS_REGION:?Set AWS_REGION.}"
: "${PROJECT:?Set PROJECT.}" "${PR_NUMBER:?Set PR_NUMBER.}" "${RUN_ID:?Set RUN_ID.}"
: "${GH_REPO:?Set GH_REPO to owner/name.}"
LINK_TTL_SECONDS="${LINK_TTL_SECONDS:-43200}"
RUN_URL="${RUN_URL:-${GITHUB_SERVER_URL:-https://github.com}/$GH_REPO/actions/runs/$RUN_ID}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

sha=$(git rev-parse HEAD)
result=$(ota-publish \
  --mode initial \
  --ipa "$IPA" \
  --bucket "$S3_BUCKET" \
  --region "$AWS_REGION" \
  --project "$PROJECT" \
  --pr "$PR_NUMBER" \
  --run-id "$RUN_ID" \
  --ttl "$LINK_TTL_SECONDS")
landing=$(printf '%s' "$result" | jq -r '.landingUrl')
expires=$(printf '%s' "$result" | jq -r '.expiresAt')

printf 'Staging build ready (commit `%s`, [run %s](%s)).\n\nOpen on your iPhone/iPad in **Safari** on a registered device, then tap Install:\n\n[📲 Install staging build](%s)\n\n_Link expires %s. Comment `/refresh-staging` on this PR for a fresh link — no rebuild needed. Comment `/build-staging` for a new build of the newest commit._\n' \
  "${sha::7}" "$RUN_ID" "$RUN_URL" "$landing" "$expires" > "$tmp/comment.md"
build_expires=$(build-expiry "$S3_BUCKET" "$PROJECT" "$PR_NUMBER" "$RUN_ID")
if [ -n "$build_expires" ]; then
  printf '\n_The build itself is deleted %s, by the lifecycle rule on the staging bucket._\n' \
    "$build_expires" >> "$tmp/comment.md"
fi

# Read the stale comments before posting, so the new comment is never among
# them.
stale-comments collect "$PR_NUMBER" "$tmp/stale-comments.jsonl"
gh pr comment "$PR_NUMBER" --body-file "$tmp/comment.md"
stale-comments hide "$tmp/stale-comments.jsonl" staged refreshed notice command
