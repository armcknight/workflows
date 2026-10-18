#!/usr/bin/env bash
# Deploys the current directory to a Fly app with Fly's remote builder, and
# the commit as the GIT_SHA build argument. Run check-tip.sh first.
#
#   APP            The Fly app. Required.
#   CONFIG         The Fly configuration file. Default: fly.toml.
#   GIT_SHA        Default: the short commit of HEAD.
#   FLY_API_TOKEN  Read by flyctl. Locally, `fly auth login` does instead.
set -euo pipefail

: "${APP:?Set APP to the Fly app.}"
CONFIG="${CONFIG:-fly.toml}"
GIT_SHA="${GIT_SHA:-$(git rev-parse --short HEAD)}"

flyctl deploy --remote-only --app "$APP" --config "$CONFIG" --build-arg GIT_SHA="$GIT_SHA"
