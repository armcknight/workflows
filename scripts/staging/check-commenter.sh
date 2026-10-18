#!/usr/bin/env bash
# Refuses a PR command from a commenter who cannot write to the repo. A command
# that mints an install link, or runs a PR's code with the repo's secrets, must
# not answer anyone else.
#
#   ASSOCIATION  The comment's author_association. Required. OWNER, MEMBER and
#                COLLABORATOR pass.
#   ACTION       What the command does, for the error. Default: run.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

: "${ASSOCIATION?Set ASSOCIATION to the author_association of the comment.}"
ACTION="${ACTION:-run}"

case "$ASSOCIATION" in
  OWNER|MEMBER|COLLABORATOR)
    echo "Commenter is $ASSOCIATION; continuing."
    ;;
  *)
    error "Commenter is $ASSOCIATION, which cannot write to this repo. Refusing to $ACTION."
    exit 1
    ;;
esac
