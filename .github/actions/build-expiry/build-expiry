#!/usr/bin/env bash
# When the bucket's lifecycle rule deletes a staging build.
#
#   build-expiry <bucket> <project> <pr-number> <run-id>
#
# Prints the time as ISO 8601 UTC, or nothing when it cannot be read (no rule
# applies, or the build is gone). Never fails, so a caller can always include
# the result when there is one.
#
# Reads metadata.json, not the IPA: ota-publish uploads both once, when it makes
# the build, so they have the same age and expire together, and metadata.json
# has a fixed name. (A refresh uploads manifest.plist and install.html again,
# so their expiry says nothing about the build.)
#
# Needs AWS credentials with s3:GetObject on the bucket. Runs on macOS (BSD
# date).

set -uo pipefail

bucket="$1" project="$2" pr="$3" run_id="$4"

# Like: expiry-date="Fri, 10 Jul 2026 00:00:00 GMT", rule-id="expire-staging"
raw=$(aws s3api head-object \
  --bucket "$bucket" \
  --key "$project/pr-$pr/run-$run_id/metadata.json" \
  --query Expiration --output text 2> /dev/null) || exit 0

expiry=$(printf '%s' "$raw" | sed -n 's/.*expiry-date="\([^"]*\)".*/\1/p')
[ -n "$expiry" ] || exit 0

date -u -j -f '%a, %d %b %Y %H:%M:%S GMT' "$expiry" '+%Y-%m-%dT%H:%M:%SZ' 2> /dev/null || true
