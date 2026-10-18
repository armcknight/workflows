#!/usr/bin/env bash
# Points a cask in a Homebrew tap at a new release, and pushes it.
#
# Clones TAP_REPO, rewrites the `version` and `sha256` lines of CASK_PATH and,
# when BINARIES is set, replaces its `binary` lines with one per binary, keeping
# the stanzas around them. Commits and pushes when anything changed. Fails when
# CASK_PATH does not exist, or when BINARIES is set and the cask has no
# `binary` line to mark where they go: this rewrites a cask, it never creates
# one.
#
#   TAP_REPO        owner/name. Required.
#   CASK_PATH       Such as Casks/work.rb. Required.
#   VERSION         Required.
#   SHA256          The release asset's sha256. Required.
#   COMMIT_MESSAGE  Default: "<cask>: bump to <VERSION>".
#   BINARIES        Executables the cask links, separated by spaces or
#                   newlines. Default: leave the binary lines alone.
#   GH_TOKEN        A token with Contents: read+write on TAP_REPO. Required.
set -euo pipefail
# shellcheck source=SCRIPTDIR/../lib.sh
. "$(dirname "$0")/../lib.sh"

: "${TAP_REPO:?Set TAP_REPO.}" "${CASK_PATH:?Set CASK_PATH.}"
: "${VERSION:?Set VERSION.}" "${SHA256:?Set SHA256.}"
COMMIT_MESSAGE="${COMMIT_MESSAGE:-$(basename "$CASK_PATH" .rb): bump to $VERSION}"
BINARIES="${BINARIES:-}"
if [ -z "${GH_TOKEN:-}" ]; then
  error "GH_TOKEN is required (a token with Contents: read+write on $TAP_REPO)."
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

git clone "https://github.com/${TAP_REPO}.git" "$work/tap"
cd "$work/tap"
# Authenticate the push with a credential helper that reads GH_TOKEN at push
# time, so the token is never written into .git/config.
git config credential.helper '!f() { echo "username=x-access-token"; echo "password=$GH_TOKEN"; }; f'

if [ ! -f "$CASK_PATH" ]; then
  error "$CASK_PATH does not exist in $TAP_REPO. Add the cask to the tap first; this rewrites a cask, it does not create one."
  exit 1
fi

sed -E \
  -e "s/^  version \".*\"$/  version \"${VERSION}\"/" \
  -e "s/^  sha256 \".*\"$/  sha256 \"${SHA256}\"/" \
  "$CASK_PATH" > "$CASK_PATH.new"
mv "$CASK_PATH.new" "$CASK_PATH"

if [ -n "${BINARIES//[[:space:]]/}" ]; then
  if ! grep -q '^  binary "' "$CASK_PATH"; then
    error "$CASK_PATH has no binary lines, so there is no place to write them."
    exit 1
  fi
  # Unquoted on purpose: one line per binary.
  # shellcheck disable=SC2086
  NEW_BINARIES="$(printf '  binary "%s"\n' $BINARIES)"
  export NEW_BINARIES
  awk '/^  binary "/ { if (!done) { print ENVIRON["NEW_BINARIES"]; done = 1 }; next } { print }' "$CASK_PATH" > "$CASK_PATH.new"
  mv "$CASK_PATH.new" "$CASK_PATH"
fi

if git diff --quiet; then
  echo "no cask changes to commit"
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add "$CASK_PATH"
git commit -m "$COMMIT_MESSAGE"
git push
