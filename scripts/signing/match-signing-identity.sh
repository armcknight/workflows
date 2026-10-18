#!/usr/bin/env bash
# Fetches the Developer ID Application certificate from the fastlane match repo
# into a new keychain, and prints its signing identity, such as
# `Developer ID Application: Name (TEAMID)`. Fails when match imports no such
# identity, or one from a team other than TEAM_ID. Delete the keychain
# afterwards with `security delete-keychain <KEYCHAIN>`.
#
# match runs readonly: it reads the encrypted certificate out of the match repo
# and makes no Apple API calls, so no Apple credentials are needed. That also
# means the certificate must already be there; create it once from a Mac with
# `fastlane match developer_id`.
#
#   KEYCHAIN        The keychain to make. Required.
#   MATCH_GIT_URL   SSH URL of the match repo. Required.
#   MATCH_PASSWORD  The match repo's passphrase. Required.
#   TEAM_ID         The team that owns the certificate. Required.
#   APP_IDENTIFIER  A bundle id. Required: match validates it even when it
#                   skips provisioning profiles, though the team-wide
#                   certificate does not use it.
#   FASTLANE        The command that runs fastlane. Default: fastlane. Set
#                   `bundle exec fastlane` to use a Gemfile's.
#
# Needs git access to the match repo (see install-match-key.sh). It changes the
# keychain search list, so it is for a CI machine. macOS only.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

: "${KEYCHAIN:?Set KEYCHAIN.}"
for name in MATCH_GIT_URL MATCH_PASSWORD TEAM_ID APP_IDENTIFIER; do
  if [ -z "${!name:-}" ]; then
    error "$name is required to fetch the signing certificate with match." >&2
    exit 1
  fi
done
FASTLANE="${FASTLANE:-fastlane}"

# A throwaway keychain, handed to match explicitly. `setup_ci` would make one,
# but it exports the keychain settings as env vars into a single fastlane
# process, and each `fastlane run` is its own process.
password="$(uuidgen)"
security create-keychain -p "$password" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$password" "$KEYCHAIN"
# The substitution must word-split: `-s` takes the new search list as separate
# arguments, so quoting it would pass every existing keychain as one path and
# drop them all.
# shellcheck disable=SC2046
security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')

# skip_provisioning_profiles: a non-sandboxed hardened-runtime app or a CLI
# needs no profile, and asking for one would need a registered App ID. match's
# output goes to stderr, so stdout holds only the identity.
# shellcheck disable=SC2086 # FASTLANE may be more than one word.
$FASTLANE run match \
  type:developer_id \
  platform:macos \
  readonly:true \
  skip_provisioning_profiles:true \
  git_url:"$MATCH_GIT_URL" \
  team_id:"$TEAM_ID" \
  app_identifier:"$APP_IDENTIFIER" \
  keychain_name:"$KEYCHAIN" \
  keychain_password:"$password" >&2

identity="$(security find-identity -v -p codesigning "$KEYCHAIN" \
  | grep 'Developer ID Application' | head -1 | sed -E 's/.*"(.*)".*/\1/' || true)"
if [ -z "$identity" ]; then
  error "match left no 'Developer ID Application' identity in the keychain. Has the certificate been created in the match repo (fastlane match developer_id)?" >&2
  security find-identity -v -p codesigning "$KEYCHAIN" >&2 || true
  exit 1
fi

cert_team="$(printf '%s' "$identity" | sed -E 's/.*\(([A-Z0-9]+)\)$/\1/')"
if [ "$cert_team" != "$TEAM_ID" ]; then
  error "The certificate belongs to team $cert_team, but team-id is $TEAM_ID." >&2
  exit 1
fi

echo "Signing identity: $identity" >&2
printf '%s\n' "$identity"
