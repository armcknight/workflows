#!/usr/bin/env bash
# Checks a request for a staging build, before any of the PR's code is checked
# out. Fails when PR_NUMBER is empty, or when the PR is not open or is from a
# fork. Under issue_comment, also fails when the commenter cannot write to the
# repo, and reacts 👀 to the comment.
#
#   PR_NUMBER    The PR to stage. Required.
#   EVENT        The event that asked for the build. Default: none.
#   ASSOCIATION  The comment's author_association, under issue_comment.
#   COMMENT_ID   The comment to react to, under issue_comment.
#   GH_TOKEN     A token with pull-requests: write.
#   GH_REPO      owner/name.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

PR_NUMBER="${PR_NUMBER:-}"
EVENT="${EVENT:-}"
here="$(dirname "$0")"

if [ -z "$PR_NUMBER" ]; then
  error "Set pr-number to stage a PR outside pull_request."
  exit 1
fi

if [ "$EVENT" = "issue_comment" ]; then
  ASSOCIATION="${ASSOCIATION:-}" ACTION=stage "$here/check-commenter.sh"
  gh api "repos/{owner}/{repo}/issues/comments/${COMMENT_ID:?Set COMMENT_ID.}/reactions" \
    -f content=eyes --silent || true
fi

# Closing a PR deletes its staging builds on purpose.
state=$("$here/pr-state.sh")
if [ "$state" != "OPEN" ]; then
  error "PR #$PR_NUMBER is $state; only an open PR from a branch in this repo is staged."
  exit 1
fi
