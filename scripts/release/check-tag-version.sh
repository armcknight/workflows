#!/usr/bin/env bash
# Checks that a release tag names the version the release ships: VERSION must
# be the base of TAG, the part before any `-`, so the tag 1.2.3-RC1 matches the
# version 1.2.3. The tag names the release, but the version in the source is
# what a user gets, so when they disagree the release ships something other
# than what it says.
#
#   TAG             Required.
#   VERSION         The version the release ships. Required.
#   VERSION_SOURCE  The file VERSION was read from, for the error. Required.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

: "${TAG:?Set TAG.}" "${VERSION_SOURCE:?Set VERSION_SOURCE.}"
VERSION="${VERSION:-}"
base="${TAG%%-*}"

if [ "$base" != "$VERSION" ]; then
  error "$VERSION_SOURCE says version ${VERSION:-(none)}, which does not match the base of tag $TAG. Bump the version in $VERSION_SOURCE before tagging."
  exit 1
fi

echo "Tag $TAG agrees with version $VERSION in $VERSION_SOURCE"
