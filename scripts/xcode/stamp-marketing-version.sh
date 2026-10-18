#!/usr/bin/env bash
# Sets the app version an xcconfig declares: rewrites its
# `MARKETING_VERSION = …` line. Fails when there is no such line.
#
#   XCCONFIG  Required.
#   VERSION   Required.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

: "${XCCONFIG:?Set XCCONFIG.}" "${VERSION:?Set VERSION.}"

if ! grep -qE '^MARKETING_VERSION' "$XCCONFIG"; then
  error "$XCCONFIG has no MARKETING_VERSION line to stamp."
  exit 1
fi

sed -E "s/^MARKETING_VERSION = .*/MARKETING_VERSION = ${VERSION}/" "$XCCONFIG" > "$XCCONFIG.new"
mv "$XCCONFIG.new" "$XCCONFIG"
grep -E '^MARKETING_VERSION' "$XCCONFIG"
