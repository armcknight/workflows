#!/usr/bin/env bash
# Asks armcknight/mcknight.io to refresh its projects page: a
# `repository_dispatch` with `event_type: release-published`, which carries the
# name of the repository that released or merged.
#
# Without SITE_DISPATCH_TOKEN it does nothing, so a repository that does not
# opt in keeps working. A failed dispatch is a warning, not a failure: the
# release or the merge has already happened, and the site refreshes on the next
# one.
#
#   SITE_DISPATCH_TOKEN  A token with Contents: read+write on SITE_REPOSITORY.
#                        Empty (the default) skips the dispatch.
#   REPOSITORY           owner/name of the repository that released or merged.
#                        Default: GITHUB_REPOSITORY.
#   SITE_REPOSITORY      Default: armcknight/mcknight.io.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

SITE_REPOSITORY="${SITE_REPOSITORY:-armcknight/mcknight.io}"
REPOSITORY="${REPOSITORY:-${GITHUB_REPOSITORY:-}}"

if [ -z "${SITE_DISPATCH_TOKEN:-}" ]; then
  echo "SITE_DISPATCH_TOKEN is not set; $SITE_REPOSITORY is not notified."
  exit 0
fi

: "${REPOSITORY:?Set REPOSITORY.}"

payload=$(printf '{"event_type":"release-published","client_payload":{"repository":"%s"}}' "$REPOSITORY")

if curl --fail --silent --show-error --retry 3 \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $SITE_DISPATCH_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -d "$payload" \
  "https://api.github.com/repos/$SITE_REPOSITORY/dispatches"; then
  echo "Notified $SITE_REPOSITORY."
  summary "Notified $SITE_REPOSITORY to refresh its projects page."
else
  warning "Could not notify $SITE_REPOSITORY. Check that SITE_DISPATCH_TOKEN can write to it."
fi
