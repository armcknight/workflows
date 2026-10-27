#!/usr/bin/env bash
# Moves the major alias tag that callers pin — `4` for the tag 4.1.0, `v1` for
# the tag v1.2.3 — to the commit of a final release tag, and pushes it.
#
# It moves nothing for a release candidate (a tag with a `-` suffix), so a
# caller pinned to the bare major never picks one up. It refuses a tag that the
# default branch does not contain, and it leaves the alias alone when a newer
# final release of the same major exists, so a patch cut on an older line never
# moves the alias backwards.
#
#   TAG             Required. The release tag, `<major>.<minor>.<patch>`.
#   SHA             The commit the tag points at. Default: the commit of TAG.
#   DEFAULT_BRANCH  Default: main.
#   REMOTE          Default: origin.
#
# Run it in a checkout that can push tags to REMOTE.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

: "${TAG:?Set TAG.}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
REMOTE="${REMOTE:-origin}"
MAJOR="${TAG%%.*}"

case "$TAG" in
  *-*)
    echo "$TAG is a release candidate. Leaving the $MAJOR alias where it is."
    exit 0
    ;;
esac

if ! printf '%s\n' "$TAG" | grep -qE "^${MAJOR}\.[0-9]+\.[0-9]+\$"; then
  error "$TAG is not a <major>.<minor>.<patch> tag. Refusing to move an alias for it."
  exit 1
fi

# A checkout fetches only the pushed ref; ask for the default branch and every
# tag explicitly rather than relying on what it left behind.
git fetch --quiet --force --tags "$REMOTE" "+refs/heads/$DEFAULT_BRANCH:refs/remotes/$REMOTE/$DEFAULT_BRANCH"

SHA="${SHA:-$(git rev-list -n 1 "refs/tags/$TAG")}"

if ! git merge-base --is-ancestor "$SHA" "$REMOTE/$DEFAULT_BRANCH"; then
  error "$TAG is not on $DEFAULT_BRANCH. Refusing to move the $MAJOR alias to a commit that $DEFAULT_BRANCH does not contain."
  exit 1
fi

# Never move the alias backwards. A patch cut on an older line — 1.1.4 while
# 1.2.0 exists — must not drag callers pinned to `1` back with it.
newest=$(git tag --list "${MAJOR}.*" \
  | grep -E "^${MAJOR}\.[0-9]+\.[0-9]+\$" \
  | sort -V \
  | tail -1)
if [ "$newest" != "$TAG" ]; then
  echo "$newest is newer than $TAG. Leaving the $MAJOR alias where it is."
  exit 0
fi

git -c user.name="github-actions[bot]" \
  -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  tag --force --annotate "$MAJOR" --message "$TAG" "$SHA"
git push --force "$REMOTE" "refs/tags/$MAJOR"

echo "$MAJOR now points at $TAG"
summary "Moved the \`$MAJOR\` alias to \`$TAG\`."
