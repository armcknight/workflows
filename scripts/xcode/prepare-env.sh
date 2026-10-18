#!/usr/bin/env bash
# Writes the .env that arkana reads, from the caller's secrets, in the current
# directory: the root of the app's checkout.
#
# First copies each committed template (.env.example, .envrc.example) to its
# gitignored name when that file is missing, so an xcodegen file group that
# lists it validates. Then writes .env with one `<key>=<value>` line for each
# key in ARKANA_KEYS that has a value in ALL_SECRETS. The match is
# case-insensitive, so the secret SENTRYDSN satisfies the key SentryDSN. A key
# with no secret is left out, and arkana fails on it, so a missing secret fails
# the build loudly. With no keys, .env is empty: that is enough for a
# project.yml that lists .env to validate.
#
#   ARKANA_KEYS  arkana key names, separated by spaces. Default: none.
#   ALL_SECRETS  A JSON object of secret names to values; in GitHub Actions,
#                `toJSON(secrets)`. Default: {}.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

ARKANA_KEYS="${ARKANA_KEYS:-}"
secrets="${ALL_SECRETS:-}"
[ -n "$secrets" ] || secrets='{}'

for ex in .env.example .envrc.example; do
  real="${ex%.example}"
  if [ -f "$ex" ] && [ ! -f "$real" ]; then
    cp "$ex" "$real"
  fi
done

: > .env
for key in $ARKANA_KEYS; do
  val=$(printf '%s' "$secrets" | jq -r --arg k "$key" \
    '[to_entries[] | select(.key | ascii_downcase == ($k | ascii_downcase))][0].value // empty')
  if [ -n "$val" ]; then
    printf '%s=%s\n' "$key" "$val" >> .env
  fi
done
