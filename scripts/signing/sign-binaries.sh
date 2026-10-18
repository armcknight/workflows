#!/usr/bin/env bash
# Developer ID signs executables in place, with the hardened runtime and a
# secure timestamp, verifies them, and zips them for notarize.sh: notarytool
# takes an archive, never a loose binary. macOS only.
#
#   KEYCHAIN  The keychain that holds the identity. Required.
#   IDENTITY  The signing identity. Required.
#   BIN_DIR   The directory the executables are in. Required.
#   BINARIES  Their names, separated by spaces or newlines. Required.
#   ZIP       The zip to write, with the signed binaries at its root. Required.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

: "${KEYCHAIN:?Set KEYCHAIN.}" "${IDENTITY:?Set IDENTITY.}" "${BIN_DIR:?Set BIN_DIR.}"
: "${BINARIES:?Set BINARIES.}" "${ZIP:?Set ZIP.}"

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

for bin in $BINARIES; do
  # --options runtime is what makes the binary eligible for notarization.
  # --timestamp is what keeps the signature valid after the cert expires.
  codesign --force --options runtime --timestamp \
    --keychain "$KEYCHAIN" --sign "$IDENTITY" "$BIN_DIR/$bin"
  codesign --verify --strict --verbose=2 "$BIN_DIR/$bin"
  cp "$BIN_DIR/$bin" "$stage/"
done

# No --keepParent: the binaries belong at the root of the zip.
ditto -c -k "$stage" "$ZIP"
