#!/usr/bin/env bash
# Waits until a server's health check answers 200, and, with REQUIRE_SHA, has
# the deployed commit in its body.
#
#   APP          The Fly app. Required.
#   URL          The server's URL. Default: https://<APP>.fly.dev.
#   HEALTH_PATH  Default: /healthz.
#   REQUIRE_SHA  `true` (the default) or `false`.
#   TIMEOUT      Seconds to wait. Default: 180.
#   GIT_SHA      The commit to look for. Default: the short commit of HEAD.
set -uo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

: "${APP:?Set APP to the Fly app.}"
URL="${URL:-}"
HEALTH_PATH="${HEALTH_PATH:-/healthz}"
REQUIRE_SHA="${REQUIRE_SHA:-true}"
TIMEOUT="${TIMEOUT:-180}"
GIT_SHA="${GIT_SHA:-$(git rev-parse --short HEAD)}"

check="${URL:-https://$APP.fly.dev}$HEALTH_PATH"
deadline=$(( $(date +%s) + TIMEOUT ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  if body=$(curl -fsS --max-time 10 "$check" 2>/dev/null); then
    if [ "$REQUIRE_SHA" != "true" ] || printf '%s' "$body" | grep -q "$GIT_SHA"; then
      echo "Deployed $GIT_SHA to $APP, and $check answers."
      summary "Deployed \`$GIT_SHA\` to \`$APP\`; [$check]($check) answers."
      exit 0
    fi
  fi
  sleep 5
done
if [ "$REQUIRE_SHA" = "true" ]; then
  error "The deploy finished, but $check did not answer with $GIT_SHA in ${TIMEOUT}s. See flyctl logs --app $APP."
else
  error "The deploy finished, but $check did not answer in ${TIMEOUT}s. See flyctl logs --app $APP."
fi
exit 1
