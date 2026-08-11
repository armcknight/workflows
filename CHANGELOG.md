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
