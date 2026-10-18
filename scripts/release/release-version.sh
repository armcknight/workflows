#!/usr/bin/env bash
# Prints the version a release tag names: the tag with any leading `v`
# removed. Fails when that is not X.Y.Z, with an optional prerelease suffix
# such as -RC1.
#
#   TAG  Required.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

: "${TAG:?Set TAG.}"
version="${TAG#v}"

if ! printf '%s' "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$'; then
  error "Tag '$TAG' is not a version tag (expected X.Y.Z or vX.Y.Z, optionally with a prerelease suffix)." >&2
  exit 1
fi

printf '%s\n' "$version"
