#!/usr/bin/env bash
# Gives git SSH read access to the fastlane match repo: writes the deploy key to
# ~/.ssh/id_ed25519 and trusts github.com's host key.
#
#   MATCH_DEPLOY_KEY  An SSH private key with read access to the match repo.
#                     Required.
#
# For a CI machine only: on a workstation it replaces your ~/.ssh/id_ed25519.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

if [ -z "${MATCH_DEPLOY_KEY:-}" ]; then
  error "MATCH_DEPLOY_KEY is required — an SSH private key with read access to the match repo."
  exit 1
fi

mkdir -p ~/.ssh
# `echo` (not printf) so the key ends with the newline OpenSSH requires,
# whether or not the stored secret kept its trailing one.
echo "$MATCH_DEPLOY_KEY" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
ssh-keyscan github.com >> ~/.ssh/known_hosts 2> /dev/null
