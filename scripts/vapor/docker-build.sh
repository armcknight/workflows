#!/usr/bin/env bash
# Builds the server's Docker image from the current directory, without pushing
# it, so that a change that breaks the image fails before a deploy.
#
#   DOCKERFILE         The Dockerfile. Default: Dockerfile.
#   GIT_SHA            Passed as the GIT_SHA build argument. Default: HEAD.
#   DOCKER_BUILD_ARGS  Extra arguments appended to `docker buildx build`, such
#                      as cache flags.
set -euo pipefail

DOCKERFILE="${DOCKERFILE:-Dockerfile}"
GIT_SHA="${GIT_SHA:-$(git rev-parse HEAD)}"
DOCKER_BUILD_ARGS="${DOCKER_BUILD_ARGS:-}"

# shellcheck disable=SC2086 # DOCKER_BUILD_ARGS is the caller's extra flags.
docker buildx build \
  --file "$DOCKERFILE" \
  --build-arg GIT_SHA="$GIT_SHA" \
  $DOCKER_BUILD_ARGS \
  .
