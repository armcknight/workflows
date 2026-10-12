#!/usr/bin/env bash
# Collect and hide the PR comments that a new staging link makes stale.
#
#   stale-comments collect <pr-number> <file>
#     Write one JSON object per stale comment to <file>, oldest first:
#     {id, isMinimized, createdAt, kind}. Run it before posting a new comment,
#     so that comment is never among them. On failure, <file> is left empty.
#
#   stale-comments hide <file> <kind...>
#     Hide the comments in <file> of the given kinds as outdated. Best-effort:
#     a comment that cannot be hidden is a warning, never a failure.
#
# Kinds:
#   staged     ios-ci's "Staging build ready" install link
#   refreshed  ota-refresh's "Refreshed staging install link"
#   notice     ota-refresh's notices: a missing build, or an expired one being
#              rebuilt
#   command    a `/refresh-staging` or `/build-staging` comment (or the old
#              `/staging-build`), from anyone
#   media      ios-ci's "UI screenshots" of the PR's UI tests
#   cli        swift-package-ci's "CLI examples" output of the PR's commands
#
# Needs GH_TOKEN with pull-requests: write, and GITHUB_REPOSITORY.

set -euo pipefail

collect() {
  local pr="$1" file="$2"
  gh api graphql --paginate \
    -f owner="${GITHUB_REPOSITORY%%/*}" \
    -f repo="${GITHUB_REPOSITORY##*/}" \
    -F pr="$pr" \
    -f query='
      query($owner: String!, $repo: String!, $pr: Int!, $endCursor: String) {
        repository(owner: $owner, name: $repo) {
          pullRequest(number: $pr) {
            comments(first: 100, after: $endCursor) {
              nodes { id isMinimized createdAt author { login } body }
              pageInfo { hasNextPage endCursor }
            }
          }
        }
      }' \
    --jq '.data.repository.pullRequest.comments.nodes[]
      | (if .author.login == "github-actions" and (.body | startswith("Staging build ready")) then "staged"
         elif .author.login == "github-actions" and (.body | startswith("Refreshed staging install link")) then "refreshed"
         elif .author.login == "github-actions" and (.body | startswith("The staging build for") or startswith("No staging build was found")) then "notice"
         elif .author.login == "github-actions" and (.body | startswith("UI screenshots")) then "media"
         elif .author.login == "github-actions" and (.body | startswith("CLI examples")) then "cli"
         elif .body | startswith("/refresh-staging") or startswith("/build-staging") or startswith("/staging-build") then "command"
         else empty end) as $kind
      | {id, isMinimized, createdAt, kind: $kind}' \
    > "$file" || {
      echo "::warning::Could not read the comments of PR #$pr; none will be hidden."
      : > "$file"
    }
}

hide() {
  local file="$1"; shift
  [ $# -gt 0 ] || { echo "stale-comments hide: name at least one kind" >&2; exit 2; }
  local id
  for id in $(jq -r --arg kinds "$*" '
      select(.isMinimized | not)
      | .kind as $k
      | select(($kinds | split(" ") | index($k)) != null)
      | .id' "$file"); do
    gh api graphql -f id="$id" -f query='
      mutation($id: ID!) {
        minimizeComment(input: { subjectId: $id, classifier: OUTDATED }) {
          minimizedComment { isMinimized }
        }
      }' --silent || echo "::warning::Could not hide stale comment $id"
  done
}

case "${1:-}" in
  collect) shift; collect "$@" ;;
  hide) shift; hide "$@" ;;
  *) echo "usage: stale-comments collect <pr-number> <file> | hide <file> <kind...>" >&2; exit 2 ;;
esac
