#!/usr/bin/env bash
# Tests a Swift package: `swift test`, in the current directory.
#
#   TEST_ARGS  Extra arguments appended to `swift test`.
#
# As with build.sh, run it in the Dockerfile's swift image to test on Linux.
set -euo pipefail

TEST_ARGS="${TEST_ARGS:-}"

# shellcheck disable=SC2086 # TEST_ARGS is the caller's extra flags.
swift test $TEST_ARGS
