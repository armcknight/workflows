#!/usr/bin/env bash
# Builds a Swift package: `swift build`, in the current directory.
#
#   PRODUCT     The executable product to build. Empty (the default) builds
#               every product.
#   BUILD_ARGS  Extra arguments appended to `swift build`.
#
# vapor-ci.yml runs it in the swift image the server's Dockerfile builds in. To
# do the same locally:
#
#   docker run --rm -v "$PWD":/src -v path/to/scripts:/scripts -w /src \
#     swift:6.0-noble /scripts/vapor/build.sh
set -euo pipefail

PRODUCT="${PRODUCT:-}"
BUILD_ARGS="${BUILD_ARGS:-}"

if [ -n "$PRODUCT" ]; then
  # shellcheck disable=SC2086 # BUILD_ARGS is the caller's extra flags.
  swift build --product "$PRODUCT" $BUILD_ARGS
else
  # shellcheck disable=SC2086
  swift build $BUILD_ARGS
fi
