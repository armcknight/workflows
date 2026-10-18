#!/usr/bin/env bash
# Creates the GitHub release for a tag, with notes from the changelog, with
# prepare-github-release (armcknight/tools). The release is a prerelease when
# the tag has a prerelease suffix (anything after a `-`) or PRERELEASE is
# `true`, so the newest final release stays the one GitHub shows as "Latest".
#
#   TAG         Required.
#   CHANGELOG   Default: CHANGELOG.md.
#   PRERELEASE  `true` or `false` (the default).
#   GH_TOKEN    A token with contents: write.
#
# Run it in a checkout with the tag's history.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

: "${TAG:?Set TAG.}"
CHANGELOG="${CHANGELOG:-CHANGELOG.md}"
PRERELEASE="${PRERELEASE:-false}"

# Two full calls rather than an array of arguments: macOS still resolves `bash`
# to 3.2, where expanding an empty array under `set -u` aborts the script —
# which would break every final release.
case "$TAG:$PRERELEASE" in
  *-*|*:true)
    prepare-github-release "$TAG" --changelog "$CHANGELOG" --prerelease
    ;;
  *)
    prepare-github-release "$TAG" --changelog "$CHANGELOG"
    ;;
esac
