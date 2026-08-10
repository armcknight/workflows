VERSION_FILE = VERSION

# A bare version file needs no --key: vrsn and prepare-release read the whole
# file as the version.

# Pinned actionlint. Its image carries shellcheck, so one container lints the
# YAML and every `run:` block in it. Keep in step with .github/workflows/ci.yml.
ACTIONLINT_VERSION = 1.7.7

# SC2016: `jq '.field'` inside single quotes is deliberate, not a lost expansion.
# SC2129: a style note on consecutive appends to one file.
# SC2015: a style note on `A && B || C`, which is guarded by `|| true` here.
# A genuine finding gets a `# shellcheck disable=` on the line, not an entry here.
SHELLCHECK_OPTS = -e SC2016 -e SC2129 -e SC2015


# MARK: - Linting

# The same check ci.yml runs, so a failure shows up before the PR.
.PHONY: lint
lint:
	docker run --rm -v "$(CURDIR)":/repo -w /repo \
	  -e SHELLCHECK_OPTS="$(SHELLCHECK_OPTS)" \
	  rhysd/actionlint:$(ACTIONLINT_VERSION) -color


# MARK: - Releasing

# Bump first, then deploy. prepare-release refuses to run when the version was
# not bumped or when [Unreleased] is empty, so a forgotten step fails before
# anything is tagged.
#
#   make minor && make deploy
#
# The tag is exactly the contents of VERSION — bare, with no `v` prefix, the same
# as armcknight/tools. release.yml then publishes the GitHub release and moves
# the major alias (`1`) that callers pin.

.PHONY: patch
patch:
	vrsn patch -f $(VERSION_FILE) --commit

.PHONY: minor
minor:
	vrsn minor -f $(VERSION_FILE) --commit

.PHONY: major
major:
	vrsn major -f $(VERSION_FILE) --commit

# A release candidate for trying a change against one caller before every caller
# gets it. Tags <version>-RC<n>; release.yml marks it a prerelease and leaves the
# major alias alone, so a caller pinned to `1` never sees it. Point one app at
# the RC tag, let a real PR build, then `make deploy`.
.PHONY: deploy-beta
deploy-beta:
	prepare-release rc --file $(VERSION_FILE) --push

.PHONY: deploy
deploy:
	prepare-release --file $(VERSION_FILE) --push
