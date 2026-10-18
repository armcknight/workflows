#!/usr/bin/env bash
# Exports a Developer ID signed app from an Xcode archive, checks it, and prints
# its path. When -exportArchive fails, falls back to the archive's built
# product. Fails unless the app is signed by a Developer ID Application
# certificate with the hardened runtime: a cask download is quarantined, so
# anything less is an app Gatekeeper refuses. macOS only.
#
#   ARCHIVE     The .xcarchive. Required.
#   EXPORT_DIR  Where the app goes. Required.
#   APP_NAME    The .app's name, without the extension. Required.
#   TEAM_ID     The team that signed it. Required.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

: "${ARCHIVE:?Set ARCHIVE.}" "${EXPORT_DIR:?Set EXPORT_DIR.}"
: "${APP_NAME:?Set APP_NAME.}" "${TEAM_ID:?Set TEAM_ID.}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>signingCertificate</key>
  <string>Developer ID Application</string>
</dict>
</plist>
PLIST

app="$EXPORT_DIR/$APP_NAME.app"
# Everything but the app's path goes to stderr, so stdout holds only the path.
if ! xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$tmp/ExportOptions.plist" >&2; then
  echo "-exportArchive failed; falling back to the archive's built product." >&2
fi
if [ ! -d "$app" ]; then
  mkdir -p "$EXPORT_DIR"
  cp -R "$ARCHIVE/Products/Applications/$APP_NAME.app" "$EXPORT_DIR/"
fi

codesign --verify --strict --deep --verbose=2 "$app" >&2
codesign -dvvv "$app" > "$tmp/codesign.txt" 2>&1
cat "$tmp/codesign.txt" >&2
if ! grep -q 'Authority=Developer ID Application' "$tmp/codesign.txt"; then
  error "$app is not signed by a Developer ID Application certificate." >&2
  exit 1
fi
if ! grep -qE 'flags=.*runtime' "$tmp/codesign.txt"; then
  error "$app is not built with the hardened runtime; notarization would fail. Set ENABLE_HARDENED_RUNTIME=YES." >&2
  exit 1
fi

printf '%s\n' "$app"
