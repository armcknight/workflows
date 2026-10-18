#!/usr/bin/env bash
# Notarizes signed code with Apple: submits a zip with notarytool and waits up
# to 30 minutes. Fails, printing Apple's log, unless it is Accepted. Stapling,
# where the code can hold a ticket, is the caller's job. macOS only.
#
#   ZIP               The archive to submit. Required.
#   NOTARY_KEY        base64 of an App Store Connect API key .p8. Required.
#   NOTARY_KEY_ID     That key's Key ID. Required.
#   NOTARY_ISSUER_ID  That key's Issuer ID. Required.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

: "${ZIP:?Set ZIP.}"
if [ -z "${NOTARY_KEY:-}" ] || [ -z "${NOTARY_KEY_ID:-}" ] || [ -z "${NOTARY_ISSUER_ID:-}" ]; then
  error "NOTARY_KEY / NOTARY_KEY_ID / NOTARY_ISSUER_ID are required. Create an App Store Connect API key with the Developer role and store the .p8 base64-encoded."
  exit 1
fi

key_dir=$(mktemp -d)
trap 'rm -rf "$key_dir"' EXIT
key="$key_dir/notary.p8"
printf '%s' "$NOTARY_KEY" | base64 --decode > "$key"

status=0
result="$(xcrun notarytool submit "$ZIP" \
  --key "$key" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID" \
  --wait --timeout 30m --output-format json)" || status=$?
echo "$result"

id="$(printf '%s' "$result" | jq -r '.id // empty' 2> /dev/null || true)"
verdict="$(printf '%s' "$result" | jq -r '.status // empty' 2> /dev/null || true)"
if [ "$verdict" != "Accepted" ] || [ "$status" -ne 0 ]; then
  error "Notarization did not succeed (status: ${verdict:-unknown})."
  if [ -n "$id" ]; then
    xcrun notarytool log "$id" \
      --key "$key" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID" || true
  fi
  exit 1
fi
