#!/usr/bin/env bash
# Prints the head branch of a PR. Tries three times, then fails: an empty
# branch makes a checkout fall back to the default branch, and a staging build
# of the wrong code.
#
#   PR_NUMBER  Required.
#   GH_TOKEN   A token that can read the repo's PRs.
#   GH_REPO    owner/name. Needed outside a checkout of the repo.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

: "${PR_NUMBER:?Set PR_NUMBER.}"

for attempt in 1 2 3; do
  ref=$(gh pr view "$PR_NUMBER" --json headRefName --jq .headRefName || true)
  if [ -n "$ref" ]; then
    printf '%s\n' "$ref"
    exit 0
  fi
  echo "Attempt $attempt to look up the head branch of PR #$PR_NUMBER failed." >&2
  sleep $((attempt * 5))
done

error "Could not look up the head branch of PR #$PR_NUMBER. Refusing to stage the default branch." >&2
exit 1
