#!/usr/bin/env bash
# Prints the state of a PR: OPEN, CLOSED or MERGED, or FORK for a PR from
# another repo, whatever its state. A fork's code must not run with this repo's
# secrets.
#
#   PR_NUMBER  Required.
#   GH_TOKEN   A token that can read the repo's PRs.
#   GH_REPO    owner/name. Needed outside a checkout of the repo.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

: "${PR_NUMBER:?Set PR_NUMBER.}"

gh pr view "$PR_NUMBER" --json state,isCrossRepository \
  --jq 'if .isCrossRepository then "FORK" else .state end'
