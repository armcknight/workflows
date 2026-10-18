# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

A caller pins a tag, so the version tracks the **caller contract**, not the
internals. The contract is larger than the `workflow_call` inputs: it also covers
everything a caller must supply — `permissions`, repo variables, inherited
secrets, and in-repo setup such as a fastlane lane, a `Brewfile` tap or an SSM
path.

- **Major** — a caller must edit its repo: an input removed or renamed, an
  optional input made required, or a new permission, variable, secret or in-repo
  file.
- **Minor** — a new optional input, a new workflow, a new capability.
- **Patch** — a fix that needs no caller change.

One tag covers every workflow here, so each entry names the workflow it belongs
to. Every major entry carries a `### Caller migration` block holding the exact
edit a caller applies.

## [Unreleased]

### Fixed

- **claude-plugin-ci, claude-plugin-release**: pass `plugin-path`,
  `marketplace-path` and `changelog` to `run:` steps through `env:`, not as
  inline `${{ inputs.* }}` expressions. Before, a value with a quote or `$(` in
  it ran as shell.

## [4.2.0] 2026-10-18

### Added

- **vapor-ci**: a new workflow for Vapor servers. It builds and tests the
  package on Linux, in the swift image the server's Dockerfile builds in, and
  builds the Docker image without pushing it. `swift-package-ci.yml` stays the
  macOS build for packages.
- **fly-deploy**: a new workflow that deploys a Fly app from the tip of the
  default branch with `--build-arg GIT_SHA=<commit>`, then waits until the
  health check answers with that commit. `deploy-on: manual` (the default)
  deploys only on `workflow_dispatch`; `merge` also deploys on each push to the
  default branch. It refuses a commit that is not the branch's tip. It needs the
  `FLY_API_TOKEN` secret, a deploy token for the app.
- **scripts/**: the shell scripts that `vapor-ci.yml` and `fly-deploy.yml`
  run, in `scripts/vapor/` and `scripts/fly/`. They have no dependency on
  GitHub Actions, so they also run locally or on a different CI provider. The
  workflows check them out at their own commit. `make lint` and the `ci`
  workflow shellcheck them, and a change to them needs a changelog entry, as a
  change to `.github/` does.
- **ios-ci**, **vapor-ci**, **fly-deploy**: an optional `working-directory`
  input, default `.`, for a repository that keeps each component in its own
  directory, such as `ios/` and `server/`. Every step that runs in the
  repository runs there, and paths such as the IPA, the test report, the
  Dockerfile and `fly.toml` are relative to it. In ios-ci,
  `ui-screenshots-path` is relative to it too. The default keeps today's
  behaviour.

## [4.1.0] 2026-10-16

### Added

- **swiftpm-cask-release**: rewrites the cask's `binary` lines from the
  `binaries` input on every release, so the cask always links what the archive
  holds. Before, only `version` and `sha256` moved, and a new executable stayed
  unlinked until someone edited the tap by hand. The cask must already have at
  least one `binary` line; a cask with none fails the release with an error.

## [4.0.0] 2026-10-12

### Changed

- **ios-ci**, **ota-refresh**: the command for a new staging build is
  `/build-staging`, not `/staging-build`, so it agrees with `/refresh-staging`.
  The comments these workflows post name the new command.
- **ios-ci**, **ota-refresh**: the workflows check the command text
  themselves, so a caller no longer gates its `issue_comment` trigger. A
  command rename is then a change in this repo only. Each check is a job-level
  `if:`, so any other comment skips the jobs before a runner starts. The
  commenter's `author_association` is checked in the jobs, as before.
- **ios-ci**: a new optional `rebuild` input. The refresh caller's `rebuild` job
  sets it, so that a `/refresh-staging` comment can start the build of an
  expired staging build.
- **stale-comments**: `/build-staging` comments are hidden as answered. Old
  `/staging-build` comments are hidden too.

  ### Caller migration
  In `.github/workflows/staging-build.yml`, delete the `if:` of the `stage`
  job. In `.github/workflows/refresh-staging-link.yml`, delete the `if:` of the
  `refresh` job, and if it has a `rebuild` job, add `rebuild: true` to that
  job's `with:`. Then move the `ios-ci.yml` and `ota-refresh.yml` pins to `@4`.
  See the README's caller examples.

### Fixed

- **ios-ci**: when the Stage job could not look up the PR's head branch, for
  example because of a network error, it checked out and staged the default
  branch, and the install link named the default branch's commit. It now tries
  the lookup three times, then fails.

## [3.1.0] 2026-10-11

### Added

- **swift-package-ci**: a new optional `cli-examples-product` input turns on a
  `cli-examples` job under `pull_request`. It runs the commands that a
  `<!-- cli-examples: … -->` marker in the PR description names, on the base
  branch and on the PR, and comments a diff of their output on the PR. The
  caller must grant `pull-requests: write` for the comment.
- **stale-comments**: a new `cli` kind for the `cli-examples` comment, so only
  the newest one stays visible.

## [3.0.0] 2026-10-08

### Changed

- **ios-ci**: a staging build is on demand. Under `pull_request` the workflow
  runs only the tests and the UI screenshots; the Stage job runs only when the
  caller sets `pr-number` from another event, such as a `/staging-build` PR
  comment. A new Authorize job runs first in that case, before any job checks
  out the PR's code: it refuses a commenter who cannot write to the repo, a
  missing `pr-number`, and a PR that is closed or from a fork, and it reacts to
  the comment. The install-link comment names `/staging-build` for a new build.
- **ota-refresh**: when the build is missing, the comment tells you to comment
  `/staging-build`, not to push a new commit.
- **stale-comments**: `/staging-build` comments are hidden as answered, the
  same as `/refresh-staging` comments.

  ### Caller migration
  iOS apps that want staging builds: add `.github/workflows/staging-build.yml`
  from the README's caller examples, with the same `ipa-name` and `arkana-keys`
  as `ci.yml`, and move the `ios-ci.yml` pins to `@3`. `ci.yml` needs no edit.

## [2.2.0] 2026-10-08

### Added

- **ota-refresh**: after it posts the refreshed install link, hide the PR's
  earlier install-link comments (the original "Staging build ready" from
  `ios-ci` and any prior refreshes) as outdated, so only the current link stays
  visible. It also hides the `/refresh-staging` command comments and the
  notices of earlier refreshes (a missing build, or an expired one being
  rebuilt). Best-effort: a comment that cannot be hidden logs a warning and does
  not fail the refresh. No caller change.
- **ota-refresh**: when the PR has no build to re-sign (the bucket's lifecycle
  rule deleted it, or an explicit `run-id` does not exist), comment the reason
  and the way to get a new build on the PR, and write an `::error::`
  annotation, instead of failing with only a log line. An explicit `run-id` is
  now checked before `ota-publish` runs. No caller change.
- **ota-refresh**: new optional inputs `rebuild-expired` (default `false`) and
  `retention-days` (default `30`), and a `rebuild` output. With
  `rebuild-expired`, a build older than `retention-days` that the bucket has
  deleted sets `rebuild` instead of failing, so a caller job can run
  `ios-ci.yml` for the PR. See the README's refresh caller example.
- **ios-ci**: new optional input `pr-number`, to build a PR's head from an event
  other than `pull_request`. Unused under `pull_request`.
- **ios-ci**: an optional `ui-screenshots` job, turned on by the new
  `ui-screenshots-scheme` and `ui-screenshots-path` inputs (with optional
  `ui-screenshots-target` and `ui-screenshots-destination`). Under
  `pull_request` it runs the UI test classes the PR adds or changes, plus any
  test named in a `<!-- ui-screenshots: … -->` marker in the PR description,
  on a simulator. It pushes the screenshots they attach to an orphan
  `ui-screenshots` branch and comments them on the PR, in a captioned table
  per test. A caller that turns
  it on must grant `contents: write`. Callers that leave it off are
  unaffected.
- **ios-ci**, **ota-refresh**: the install-link comment also says when the
  build itself is deleted, as read from the staging bucket's lifecycle rule
  (`head-object` on the build's `metadata.json`). The line is left out when no
  rule applies. Shared through the new `build-expiry` composite action. No
  caller change.
- **ios-ci**: after the Stage job posts its install link, hide the PR's stale
  comments the same way ota-refresh does. Both workflows share this through the
  new `stale-comments` composite action. No caller change.

### Fixed

- **ota-refresh**: decide that a build exists by its `metadata.json`, not by
  its `run-*` prefix. A refresh uploads `manifest.plist` and `install.html`
  again, so after an earlier refresh the prefix outlives the build, and the
  refresh failed inside `ota-publish` instead of explaining the missing build.
- **ios-ci**: trust the `armcknight/tools` tap before `brew bundle`, which
  Homebrew now refuses to load from an untrusted tap. A caller's `Brewfile`
  must install the tools as a cask, `cask 'armcknight/tools/tools'`: the tap no
  longer has a formula of that name.

## [2.1.0] 2026-08-10

### Added

- **github-release**: a new reusable workflow that publishes a GitHub release
  from the tagged changelog section, optionally attaching files. For repos with
  nothing to build, sign or upload, where tagging *is* the release — a SwiftPM
  library resolved from the tag, or a Spoon repo installed off the branch.
  `armcknight/swift-armcknight` and `armcknight/hammerspoons` had each grown a
  near-identical copy of this; both now call it.

  Every input is optional: `changelog`, `assets`, `prerelease`, `runs-on`. A tag
  with a prerelease suffix is marked a prerelease regardless of the input. The
  workflow runs no caller-supplied commands — a caller gating the release on a
  check puts it in its own job and depends on it with `needs:`.

## [2.0.0] 2026-08-10

### Added

- **swiftpm-cask-release**: a `bundle-id` input, passed to `fastlane match` as
  `app_identifier`. match requires it even for a `developer_id` fetch with
  `skip_provisioning_profiles` — without it signing aborted with "No value found
  for 'app_identifier'". It is unused for the team-wide Developer ID certificate,
  but the caller supplies its own value so the workflow carries no identity.

  ### Caller migration
  Only callers that set `sign: true`: add a `bundle-id` input (e.g.
  `bundle-id: com.example.<tool>`).

## [1.2.0] 2026-08-10

### Added

- **swift-package-ci** and **swiftpm-cask-release**: a `submodules` input,
  passed straight to `actions/checkout`. A package whose dependencies are
  vendored as git submodules (path-based SwiftPM deps) sets `submodules:
  recursive` so the build can see them; the default (empty) is unchanged, so
  existing callers are unaffected.

## [1.1.0] 2026-08-10

### Changed

- **swiftpm-cask-release**: the optional `sign` path now reads the Developer ID
  Application certificate from a fastlane match repo (readonly), matching
  `macos-cask-release`, instead of importing a base64 `.p12`. New inputs
  `match-git-url` + `team-id`; secrets `DEVELOPER_ID_P12_BASE64` /
  `DEVELOPER_ID_P12_PASSWORD` are replaced by `MATCH_PASSWORD` /
  `MATCH_DEPLOY_KEY`. A signing caller needs no Gemfile (the runner's fastlane
  is used). Callers that leave `sign` off (the default) are unaffected.

  ### Caller migration
  Only callers that set `sign: true`: add the `match-git-url` and `team-id`
  inputs, and provide `MATCH_PASSWORD` + `MATCH_DEPLOY_KEY` (drop the
  `DEVELOPER_ID_P12_*` secrets). `NOTARY_*` unchanged.

## [1.0.1] 2026-08-10

### Fixed

- **swiftpm-cask-release**: authenticate the tap push with a git credential
  helper that reads `TAP_RELEASE_TOKEN` at push time, instead of embedding the
  token in the clone URL — so the token no longer lands in the checkout's
  `.git/config`. No caller change.

## [1.0.0] 2026-08-10

### Added
- `ios-ci.yml` — reusable PR pipeline for iOS apps: run the fastlane `test` lane,
  then build an ad-hoc IPA, upload it to a private S3 bucket and comment a 12 h
  presigned OTA install link on the PR.
- `ota-refresh.yml` — re-sign the install link for a PR's newest (or a given)
  build, on a `/refresh-staging` comment or `workflow_dispatch`, with no rebuild.
  Re-checks `author_association` itself, so a caller that omits the `if:` gate
  fails closed.
- `ota-cleanup.yml` — delete a PR's S3 prefix when the PR closes.
- `macos-cask-release.yml` — reusable release pipeline for macOS apps in the
  `armcknight/homebrew-tools` tap: archive, Developer ID sign with a hardened
  runtime, notarize and staple, attach the zip to a release on the tap repo and
  to the caller repo's own release, then bump `version` and `sha256` in the cask.
- `swift-package-ci.yml` — `swift build` and `swift test` for SwiftPM packages,
  with a caller-chosen runner and extra arguments for each command.
- `swiftpm-cask-release.yml` — reusable release pipeline for SwiftPM command-line
  tools in the `armcknight/homebrew-tools` tap: check the tag against the version
  compiled into the source, `swift build -c release`, tar the named executables,
  attach the tarball to a release on the tap repo, then bump `version` and
  `sha256` in the cask. A final tag routes to `Casks/<cask-name>.rb` and a release
  candidate to `Casks/<cask-name>-rc.rb`, so an RC leaves the stable channel
  alone. With `sign: true` it also Developer ID signs each binary in a throwaway
  keychain and notarizes them; it does not staple, because `stapler` writes into
  a bundle and these are bare executables. Factors out the near-identical inline
  `release.yml` files in `armcknight/workr` and `armcknight/tools`.
- `claude-plugin-ci.yml` — validate a Claude Code plugin manifest and its
  marketplace manifest on every PR.
- `claude-plugin-release.yml` — validate both manifests, refuse a tag that
  disagrees with the plugin manifest version, and create the GitHub release from
  the changelog section.
- Release tooling for this repo: a `VERSION` file, this changelog, a `Makefile`
  wrapping `vrsn` and `prepare-release`, a `ci.yml` that lints every workflow
  with actionlint and requires a changelog entry, and a `release.yml` that
  publishes the GitHub release and moves the major alias tag. The README gains a
  "Versioning and pinning" section, and its caller examples now pin `@1`.
