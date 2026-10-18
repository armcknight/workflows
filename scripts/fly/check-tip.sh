#!/usr/bin/env bash
# Refuses to go on unless the checkout in the current directory is the tip of
# the default branch on origin, with no changes. `fly deploy` puts the checkout
# on the server, so this keeps code off the server that is not on the default
# branch: a run started from another branch, a rerun of an old push, or local
# edits.
#
#   DEFAULT_BRANCH  The branch to compare with. Default: main.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"

head=$(git rev-parse HEAD)
# ls-remote, not fetch: it changes nothing in the local clone.
tip=$(git ls-remote --exit-code origin "refs/heads/$DEFAULT_BRANCH" | cut -f1)
if [ "$head" != "$tip" ]; then
  error "The checkout is at $head, but $DEFAULT_BRANCH is at $tip. Deploy only the tip of $DEFAULT_BRANCH."
  exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
  error "The checkout has changes."
  git status --short
  exit 1
fi
echo "$head is the tip of $DEFAULT_BRANCH."
