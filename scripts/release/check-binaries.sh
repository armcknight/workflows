#!/usr/bin/env bash
# Checks that a build made each executable a release ships. Fails on the first
# one that is not a file in BIN_DIR.
#
#   BIN_DIR   Required.
#   BINARIES  Names, separated by spaces or newlines. Required.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

: "${BIN_DIR:?Set BIN_DIR.}" "${BINARIES:?Set BINARIES.}"

for bin in $BINARIES; do
  if [ ! -f "$BIN_DIR/$bin" ]; then
    error "$BIN_DIR/$bin does not exist. Is '$bin' an executable product of this package?"
    exit 1
  fi
done
