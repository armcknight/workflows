#!/usr/bin/env bash
# Deletes all of a PR's staging builds: s3://<S3_BUCKET>/<PROJECT>/pr-<PR_NUMBER>/.
#
#   S3_BUCKET  Required.
#   PROJECT    The repo's name, which namespaces its builds. Required.
#   PR_NUMBER  Required.
#
# Needs AWS credentials that can delete from the bucket.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

: "${S3_BUCKET:?Set S3_BUCKET.}" "${PROJECT:?Set PROJECT.}" "${PR_NUMBER:?Set PR_NUMBER.}"

echo "Removing s3://$S3_BUCKET/$PROJECT/pr-$PR_NUMBER/"
aws s3 rm "s3://$S3_BUCKET/$PROJECT/pr-$PR_NUMBER/" --recursive
