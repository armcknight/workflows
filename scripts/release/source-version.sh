#!/usr/bin/env bash
# Prints the version compiled into a tool, read from its source: the first
# match of VERSION_REGEX's capture group in VERSION_FILE.
#
#   VERSION_FILE   Required.
#   VERSION_REGEX  A `sed -E` expression with exactly one capture group around
#                  the version, such as `.*static let version = "([^"]+)".*`.
#                  Required.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

: "${VERSION_FILE:?Set VERSION_FILE.}"
if [ -z "${VERSION_REGEX:-}" ]; then
  error "version-file is set but version-regex is empty. Both are needed to read the version." >&2
  exit 1
fi
if [ ! -f "$VERSION_FILE" ]; then
  error "version-file $VERSION_FILE does not exist." >&2
  exit 1
fi

version="$(sed -nE "s/${VERSION_REGEX}/\1/p" "$VERSION_FILE" | head -1)"
if [ -z "$version" ]; then
  error "version-regex matched nothing in $VERSION_FILE. It needs exactly one capture group around the version." >&2
  exit 1
fi

printf '%s\n' "$version"
