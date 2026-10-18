#!/usr/bin/env bash
# Fails unless DEPLOY_ON is `manual` or `merge`, the two values fly-deploy.yml
# takes.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

case "${DEPLOY_ON:-}" in
  manual|merge) ;;
  *) error "deploy-on is '${DEPLOY_ON:-}'; it must be manual or merge."; exit 1 ;;
esac
