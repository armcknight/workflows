#!/usr/bin/env bash
# Prints the cask in a tap that a release tag updates: Casks/<CASK_NAME>.rb for
# a final tag (1.2.3), and Casks/<CASK_NAME>-rc.rb for a tag with a prerelease
# suffix (1.2.3-RC1, as `prepare-release rc` names it), so a release candidate
# never disturbs the stable channel.
#
#   CASK_NAME  Required.
#   TAG        Required.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

: "${CASK_NAME:?Set CASK_NAME.}" "${TAG:?Set TAG.}"

case "$TAG" in
  *-*) printf 'Casks/%s-rc.rb\n' "$CASK_NAME" ;;
  *) printf 'Casks/%s.rb\n' "$CASK_NAME" ;;
esac
