# armcknight/workflows

Reusable GitHub Actions workflows shared across armcknight repos. Five areas:

- **staging OTA** (iOS) — on every PR, run tests. On a `/build-staging`
  comment, build an ad-hoc IPA and publish a presigned [`itms-services`](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices)
  over-the-air install link to a private S3 bucket, commented on the PR.
- **macOS cask release** — on a version tag, build, sign, and notarize a macOS
  app, then publish it through the `armcknight/homebrew-tools` Homebrew tap.
- **SwiftPM package CI** — `swift build` and `swift test` on every PR.
- **Vapor server on Fly.io** — build and test on Linux and build the Docker
  image on every PR, and deploy to Fly by hand or on a merge.
- **Claude Code plugin** — validate the plugin and marketplace manifests on every
  PR, and cut the release on a version tag.

Callers pin the moving major tag: `@1`. See
[Versioning and pinning](#versioning-and-pinning).

## Why S3 + presigned links

iOS won't install a bare `.ipa`; OTA install needs an
`itms-services://?action=download-manifest&url=…manifest.plist` link, and the
device's install daemon fetches the manifest and IPA with **no cookies or
headers**. GitHub release assets on a private repo require auth, so the daemon
can't fetch them — but **S3 presigned URLs carry their auth in the query
string**, so it can. The heavy lifting (presign IPA → render `manifest.plist` →
wrap in an `install.html` landing page → emit a link) is done by the
[`ota-publish`](https://github.com/armcknight/tools) CLI from the
`armcknight/tools` Homebrew tap.

## Workflows

| File | Trigger (in caller) | What it does |
|------|--------------------|--------------|
| `ios-ci.yml` | `pull_request`, and `issue_comment` `/build-staging` | Under `pull_request`: the `test` job, and the optional `ui-screenshots` job beside it, which runs the UI tests the PR adds or changes and comments their screenshots. On a `/build-staging` comment (with `pr-number` set): the `authorize` job, then `test`, then the `stage` job: build the ad-hoc IPA, upload to S3, comment a 12 h install link and the time the bucket deletes the build, and hide the PR's stale install links, refresh notices and `/refresh-staging` and `/build-staging` commands. |
| `ota-refresh.yml` | `issue_comment` `/refresh-staging` or `workflow_dispatch` | Re-sign the link for a PR's latest (or given) build — no rebuild. Earlier install-link comments, earlier refresh notices and the `/refresh-staging` and `/build-staging` commands are hidden as outdated. When the build is gone, comment why on the PR; if the bucket's lifecycle rule deleted it, optionally hand off to `ios-ci.yml` to rebuild. |
| `ota-cleanup.yml` | `pull_request: closed` | Delete the PR's S3 prefix. |
| `macos-cask-release.yml` | `push` of a version tag | Build + Developer ID sign + notarize + staple a macOS app, attach the zip to a release on the tap repo, bump the cask. |
| `swift-package-ci.yml` | `pull_request` | `swift build` and `swift test` for a SwiftPM package, and the optional `cli-examples` job beside them, which runs the commands the PR description names on the base branch and on the PR and comments the change in their output. |
| `vapor-ci.yml` | `pull_request` | `swift build` and `swift test` for a Vapor server on Linux, in the swift image the Dockerfile builds in, and a build of the Docker image, not pushed. Separate from `swift-package-ci.yml`, which runs on macOS. |
| `fly-deploy.yml` | `workflow_dispatch`, and `push` to the default branch | Deploy the default branch's tip to Fly with `--build-arg GIT_SHA=<commit>`, then wait until the health check answers with that commit. `deploy-on: manual` deploys only on `workflow_dispatch`; `merge` also on each push to the default branch. Refuses a commit that is not the branch's tip. |
| `swiftpm-cask-release.yml` | `push` of a version tag | Build a SwiftPM CLI, optionally sign + notarize it, attach the tarball to a release on the tap repo, bump the cask. |
| `claude-plugin-ci.yml` | `pull_request` | Validate a Claude Code plugin manifest and its marketplace manifest. |
| `claude-plugin-release.yml` | `push` of a version tag | Validate both manifests, refuse a tag that disagrees with the plugin version, create the GitHub release. |
| `github-release.yml` | `push` of a version tag | Create the GitHub release from the changelog section, optionally attaching files. For repos where tagging *is* the release. |

`ci.yml` and `release.yml` are this repo's **own** CI, not part of that list. They
have no `workflow_call` trigger, so a caller cannot `uses:` them.

S3 layout (one bucket, namespaced per project): `s3://<bucket>/<repo>/pr-<n>/run-<id>/`.

### Inputs

`ios-ci.yml`:

| Input | Required | Description |
|-------|----------|-------------|
| `ipa-name` | yes | Base name of the IPA produced by `fastlane stage`, without `.ipa`. |
| `arkana-keys` | yes | Space-separated arkana key **names**. Values are resolved from the caller's secrets by name, so no secret values pass through `with:`. |
| `run-tests` | no (`true`) | Run the fastlane `test` lane first. Set `false` for apps with no unit-test scheme. |
| `pr-number` | no (none) | PR to stage when the trigger is not `pull_request`: the `/build-staging` caller or the rebuild job in the refresh caller below. Setting it is what makes a staging build. Leave it out under `pull_request`. |
| `rebuild` | no (`false`) | Set `true` only in the refresh caller's `rebuild` job. A `/refresh-staging` comment then starts the build, in place of `/build-staging`. |
| `ui-screenshots-scheme` | no (none) | Scheme that runs the UI tests. Setting it turns on the `ui-screenshots` job. |
| `ui-screenshots-path` | with the scheme | Directory of the UI test sources, relative to `working-directory`. Each `XCTestCase` class in a Swift file the PR adds or changes there is run with `-only-testing`, along with any test the PR description names (below). |
| `ui-screenshots-target` | no (the scheme) | UI test target name, for `-only-testing`. |
| `ui-screenshots-destination` | no (newest iPhone simulator) | `xcodebuild` destination. |
| `working-directory` | no (`.`) | Directory of the app, relative to the repository root, such as `ios`. Bundler, Homebrew, arkana, xcodegen, fastlane and `xcodebuild` run there, so the `Gemfile`, `Brewfile`, project spec and `fastlane/` are there; the IPA, test report, test artifact and screenshots are read from there. |

A PR can also name tests it does not change — say, an existing test that goes
to the screen a fix changes — in a hidden marker in its description:

```html
<!-- ui-screenshots: DailyRollupUITests/testHistorySummaryAndAllEventsModes, OtherTests -->
```

IDs are `[<target>/]<class>[/<method>]`, separated by spaces, commas or
newlines. The job reads the description of the event that started the run, so
an edit to the description takes effect on the next push.

The `ui-screenshots` job runs only under `pull_request`. It collects the PNGs
the tests attach (`XCTAttachment` with `lifetime = .keepAlways`), commits them
to an orphan `ui-screenshots` branch under `pr-<n>/<sha7>/`, and comments them
on the PR, one captioned table per test, hiding its earlier screenshot
comment. The images are linked as
`blob/ui-screenshots/…?raw=true`, which GitHub serves from a private repo to
signed-in viewers who can read it. Because it pushes that branch, the caller
must grant `contents: write`; the other jobs still ask for read only. A failed
UI test still posts its screenshots, then fails the job.

A staging build is on demand: under `pull_request` there is no `stage` job, so a
push costs only the tests. Under `issue_comment`, every job is skipped, with no
runner, unless the comment is `/build-staging` on a PR (or `/refresh-staging`
with `rebuild` set). The caller does not check the command text. When the
trigger is not `pull_request`, the
`authorize` job runs before any job checks out the PR's code. It refuses a
commenter who cannot write to the repo, a missing `pr-number`, and a PR that is
closed or from a fork, and reacts 👀 to the comment. Then `test` runs (unless
`run-tests` is `false`), and `stage` runs only if the tests pass.

`ota-refresh.yml`: `pr-number` (required), `run-id` (optional — defaults to the
PR's newest build), `comment-id` (optional — the comment to react to),
`rebuild-expired` (optional, `false`) and `retention-days` (optional, `30` — the
age at which the staging bucket's lifecycle rule deletes a build). Under
`issue_comment`, the job is skipped, with no runner, unless the comment is
`/refresh-staging` on a PR.

When the PR has no build to re-sign, the workflow comments the reason on the PR
and fails. The one exception: the newest "Staging build ready" comment is older
than `retention-days`, `rebuild-expired` is `true`, and the PR is open and not
from a fork. Then it comments that it is rebuilding and sets the output
`rebuild` to `'true'`, and the caller's `rebuild` job runs `ios-ci.yml` for the
PR, which posts a new install link.

`ota-cleanup.yml`: no inputs.

`macos-cask-release.yml`:

| Input | Required | Description |
|-------|----------|-------------|
| `scheme` | yes | Xcode scheme to archive. |
| `app-name` | yes | Name of the built `.app` bundle, without the extension. |
| `cask-name` | yes | Cask base name in the tap (`Casks/<cask-name>.rb`). Also the prefix of the tap release and its asset. |
| `match-git-url` | yes | SSH URL of the fastlane match repo holding the Developer ID cert. |
| `team-id` | yes | Apple Developer Portal team that owns that cert. Checked against the cert match hands back. |
| `app-identifier` | yes | The app's bundle id. Unused for signing, but `match` validates the option even with `skip_provisioning_profiles` and fails without it. |
| `project` | no (`<scheme>.xcodeproj`) | Path to the `.xcodeproj`. |
| `version-xcconfig` | no (none) | xcconfig whose `MARKETING_VERSION` is stamped from the tag. Omit to leave the version alone. |
| `arkana-keys` | no (none) | Space-separated arkana key **names**, same resolution as `ios-ci.yml`. |
| `run-xcodegen` | no (`true`) | Run `xcodegen` before building. |
| `tap-repo` | no (`armcknight/homebrew-tools`) | Tap that hosts the cask and the release asset. |
| `create-source-release` | no (`true`) | Also create a release on the caller repo, with generated notes. |
| `runs-on` | no (`macos-26`) | Runner label. |

Outputs: `version`, `asset`, `sha256`.

`swift-package-ci.yml`:

| Input | Required | Description |
|-------|----------|-------------|
| `runs-on` | no (`macos-15`) | Runner label. |
| `build-args` | no (none) | Appended to `swift build`. |
| `test-args` | no (none) | Appended to `swift test`. |
| `submodules` | no (none) | Passed to `actions/checkout`. |
| `cli-examples-product` | no (none) | Executable product that the PR's example commands run. Setting it turns on the `cli-examples` job. |

A PR shows its CLI change with example commands in a hidden marker in its
description, one command on each line:

```html
<!-- cli-examples:
mytool list
mytool list --json
$ mytool sync --dry-run "My Folder"
-->
```

The `cli-examples` job runs only under `pull_request`. It builds the product on
the PR and on the base branch, runs each command on both (in the root of each
checkout, with no stdin, `NO_COLOR=1`, `TERM=dumb`, and a 60-second limit), and
comments on the PR: a diff of the two outputs and the PR's output for each
command, with the exit status when it is not 0 or when it changes. It hides its
earlier comment. When the base branch does not build the product (a new tool,
for example), the comment shows only the PR's output.

The commands are not given to a shell. Each line is split into words as a
shell would split it, with quotes, and the first word must be the product name.
Pipes, redirections, variables and globs do not work. A line that does not
start with the product name is skipped with a warning. At most 20 commands run.

The job reads the description of the event that started the run, so an edit to
the description takes effect on the next push. To comment, the caller must
grant `pull-requests: write`. Without it, or on a PR from a fork, the job puts
the output in its summary and gives a warning.

`vapor-ci.yml`:

| Input | Required | Description |
|-------|----------|-------------|
| `swift-image` | yes | The swift image to build and test in, such as `swift:6.0-noble`. Keep it the same as the Dockerfile's build image. |
| `product` | no (every product) | The executable product to build. |
| `build-args` | no (none) | Appended to `swift build`. |
| `run-tests` | no (`true`) | Run `swift test` after the build. |
| `test-args` | no (none) | Appended to `swift test`. |
| `submodules` | no (none) | Passed to `actions/checkout`. |
| `docker-build` | no (`true`) | Build the Docker image, without pushing it. |
| `dockerfile` | no (`Dockerfile`) | The Dockerfile, relative to `working-directory`. |
| `working-directory` | no (`.`) | Directory of the package, relative to the repository root, such as `server`. `swift build`, `swift test` and the Docker build run there: it is the Docker build context, and `.build` is cached from there. |

`fly-deploy.yml`:

| Input | Required | Description |
|-------|----------|-------------|
| `app` | yes | The Fly app. |
| `deploy-on` | no (`manual`) | `manual`: deploy only on `workflow_dispatch`. `merge`: also on each push to the default branch. Any other value fails the run. |
| `health-check-path` | no (`/healthz`) | The path that answers 200, with the deployed commit in its body, when the server is ready. |
| `url` | no (`https://<app>.fly.dev`) | The server's URL, for the health check. |
| `require-sha` | no (`true`) | Wait for the commit in the health check's body, not only a 200. |
| `health-timeout-seconds` | no (`180`) | How long to wait for the health check. |
| `config` | no (`fly.toml`) | The Fly configuration file, relative to `working-directory`. |
| `working-directory` | no (`.`) | Directory of the server, relative to the repository root, such as `server`. `flyctl deploy` runs there, so the `fly.toml` and the Docker build context are there. |

Secret: `FLY_API_TOKEN`, a deploy token for the one app (`fly tokens create
deploy --app <app>`), passed explicitly. The server's own secrets, such as
`DATABASE_URL`, are Fly secrets, not GitHub secrets, and this workflow never
reads them.

A deploy is the owner's action. The caller triggers on both `workflow_dispatch`
and `push` to the default branch, so that `deploy-on` is the only edit between
the two ways; under `manual` the push run's deploy job is skipped. Deploys of an
app run one at a time, and a started deploy is never cancelled. As
`fly deploy` puts the checkout on the server, the job refuses a commit that is
not the tip of the default branch: a run started from another branch, or a
rerun of an old push.

Both workflows only check out and call the scripts in [`scripts/`](scripts),
which do the work. The scripts take their inputs as environment variables, have
no dependency on GitHub Actions, and each one documents its variables at the
top, so you can run them locally or from a different CI provider. The workflows
check them out at the commit of the workflow (`job.workflow_sha`), so a caller
that pins `@4` also gets the `@4` scripts. To deploy by hand, from the server's
checkout of the default branch (in its `working-directory`):

```sh
export APP=my-server
path/to/workflows/scripts/fly/check-tip.sh
path/to/workflows/scripts/fly/deploy.sh
path/to/workflows/scripts/fly/wait-for-health.sh
```

To build and test on Linux as `vapor-ci.yml` does:

```sh
docker run --rm -v "$PWD":/src -v path/to/workflows/scripts:/scripts -w /src \
  swift:6.0-noble sh -c '/scripts/vapor/build.sh && /scripts/vapor/test.sh'
```

`swiftpm-cask-release.yml`:

| Input | Required | Description |
|-------|----------|-------------|
| `cask-name` | yes | Cask base name in the tap (`Casks/<cask-name>.rb`). Also the prefix of the tap release and its asset. |
| `binaries` | yes | Executables to take from `.build/release`, separated by spaces or newlines. |
| `version-file` | no (none) | File holding the version compiled into the tool, checked against the tag. Omit to skip that check. |
| `version-regex` | no (none) | `sed -E` expression with one capture group that reads the version out of `version-file`. Needed when `version-file` is set. |
| `tap-repo` | no (`armcknight/homebrew-tools`) | Tap that hosts the cask and the release asset. |
| `sign` | no (`false`) | Developer ID sign and notarize each binary before packaging. |
| `runs-on` | no (`macos-15`) | Runner label. Must be macOS. |

Secrets: `TAP_RELEASE_TOKEN` is always required. With `sign: true`, so are
`DEVELOPER_ID_P12_BASE64`, `DEVELOPER_ID_P12_PASSWORD`, `NOTARY_KEY`,
`NOTARY_KEY_ID` and `NOTARY_ISSUER_ID` — GitHub cannot make a secret
conditionally required, so the workflow names the missing one at run time rather
than shipping an unsigned build.

A final tag (`1.2.3`) routes to `Casks/<cask-name>.rb`; a release candidate
(`1.2.3-RC1`, as `prepare-release rc` names it) routes to
`Casks/<cask-name>-rc.rb`, so an RC never disturbs the stable channel. The
cask's `binary` lines are rewritten from `binaries` on every release, so a new
executable needs no hand edit in the tap; the cask must already have at least
one `binary` line to mark where they go. Signing is optional here, unlike `macos-cask-release.yml` where
it is mandatory: Homebrew quarantines every cask download, but a `binary`
artifact run from a shell does not face the Gatekeeper launch check a `.app`
does. There is no stapling step — `stapler` writes a ticket into a bundle, a
`.dmg` or a `.pkg`, and these are bare executables, so Gatekeeper looks the
ticket up online instead.

```yaml
jobs:
  release:
    uses: armcknight/workflows/.github/workflows/swiftpm-cask-release.yml@1
    with:
      cask-name: work
      binaries: work
      version-file: Sources/work/CLI/Work.swift
      version-regex: '.*static let version = "([^"]+)".*'
    secrets: inherit
```

`claude-plugin-ci.yml` and `claude-plugin-release.yml`: `plugin-path` (required),
`marketplace-path` (optional, `.`), `runs-on` (optional). `claude-plugin-release.yml`
also takes `changelog` (optional, `CHANGELOG.md`) and `prerelease` (optional).

`github-release.yml`: every input is optional — `changelog` (`CHANGELOG.md`),
`assets` (whitespace-separated paths or globs to attach; nothing by default),
`prerelease`, and `runs-on`. A tag with a prerelease suffix is marked a
prerelease whether or not the input is set.

```yaml
jobs:
  release:
    permissions:
      contents: write
    uses: armcknight/workflows/.github/workflows/github-release.yml@2
    with:
      assets: Spoons/*.spoon.zip
```

## Running the steps outside Actions

Every workflow here works as `vapor-ci.yml` and `fly-deploy.yml` do: the work
is in the scripts in [`scripts/`](scripts), and a step only sets their
environment variables and calls them. The scripts have no dependency on GitHub
Actions, and each one names the variables it reads at the top, so the same
operation runs on a workstation or on a different CI provider. A script that
gives a value back prints it on stdout, and the workflow writes it to
`$GITHUB_OUTPUT`. The workflows check the scripts out at the commit of the
workflow (`job.workflow_sha`), so a caller that pins `@4` also gets the `@4`
scripts.

| Directory | Scripts | Used by |
|-----------|---------|---------|
| `scripts/staging/` | `authorize.sh`, `check-commenter.sh`, `pr-state.sh`, `pr-head-ref.sh`, `publish.sh`, `refresh.sh`, `cleanup.sh` | `ios-ci.yml`, `ota-refresh.yml`, `ota-cleanup.yml` |
| `scripts/xcode/` | `prepare-env.sh`, `stamp-marketing-version.sh`, `export-app.sh` | `ios-ci.yml`, `macos-cask-release.yml` |
| `scripts/signing/` | `install-match-key.sh`, `match-signing-identity.sh`, `sign-binaries.sh`, `notarize.sh` | `ios-ci.yml`, `macos-cask-release.yml`, `swiftpm-cask-release.yml` |
| `scripts/release/` | `release-version.sh`, `source-version.sh`, `check-tag-version.sh`, `check-binaries.sh`, `cask-path.sh`, `bump-cask.sh`, `publish-github-release.sh` | `macos-cask-release.yml`, `swiftpm-cask-release.yml`, `github-release.yml`, `claude-plugin-release.yml` |

For example, to re-sign a PR's staging link by hand:

```sh
export S3_BUCKET=my-bucket AWS_REGION=us-east-1 PROJECT=my-app PR_NUMBER=42 GH_REPO=me/my-app
PATH="$PWD/.github/actions/stale-comments:$PWD/.github/actions/build-expiry:$PATH" \
  scripts/staging/refresh.sh
```

The staging scripts also need `stale-comments` and `build-expiry` on `PATH`.
Those, and `ui-screenshots` and `cli-examples`, are still composite actions in
`.github/actions/`, which the workflows use pinned to `@main`.
`install-match-key.sh` and `match-signing-identity.sh` change the machine they
run on (`~/.ssh/id_ed25519`, the keychain search list), so they are for a CI
machine, not a workstation.

## Versioning and pinning

Every workflow here is versioned together under one tag, with semver applied to
the **caller contract**. That contract is larger than the `workflow_call` inputs:
it also covers what a caller must supply — `permissions`, repo variables,
inherited secrets, and in-repo setup such as a fastlane lane or a `Brewfile` tap.
A change that makes a caller edit its repo is a major change. `CHANGELOG.md`
states the rules, and names the workflow in every entry, because one tag covers
all of them.

There are two kinds of tag:

| Tag | Moves? | Pin to it when |
|-----|--------|----------------|
| `1` | Yes — always the newest `1.x.y`. | Normal use. Fixes and new optional inputs reach you with no PR, and a breaking change cannot reach you by accident. |
| `1.2.3` | Never. | You need the build reproducible, or you are trying one app against a release candidate. |

```yaml
uses: armcknight/workflows/.github/workflows/ios-ci.yml@1
```

Tags are bare, with no `v` prefix, the same as `armcknight/tools`. A release
candidate carries an `-RC<n>` suffix and never moves the `1` alias, so a caller
pinned to `1` never picks one up.

A major bump is a signal, not a failure. Read that release's `### Caller
migration` block, apply the edit it names, and move the pin to `2`.

### Cutting a release

The `make` targets wrap `vrsn` and `prepare-release` from `armcknight/tools`:

```
make minor      # or patch / major — bumps VERSION and commits
make deploy     # migrates [Unreleased] into the new section, tags, pushes
```

`prepare-release` refuses to run when `VERSION` was not bumped, or when
`[Unreleased]` is empty, so a forgotten step fails before anything is tagged. Use
`make deploy-beta` for an `-RC<n>` instead, to try a change against one app before
every app gets it.

Pushing the tag starts `release.yml` here. It publishes the GitHub release from
the changelog section and moves the major alias. It refuses a tag that is not on
`main`, and it leaves the alias alone when you cut a patch on an older line, so
the alias never moves backwards.

`make lint` runs the same checks `ci.yml` runs — actionlint on the workflows,
and shellcheck on `scripts/` and the scripts in `.github/actions/` — so a lint
failure shows up before the PR.

`make` (or `make help`) lists every target with a one-line description.

## Caller requirements — OTA workflows

**Repo variables** (read from the caller automatically — `vars` propagate into
reusable workflows; only secrets need `inherit`):
- `AWS_ROLE_ARN` — IAM role assumed via GitHub OIDC (no long-lived keys)
- `AWS_REGION`
- `S3_BUCKET`

**Repo secrets** (passed with `secrets: inherit`):
- `MATCH_PASSWORD`, `MATCH_DEPLOY_KEY` — fastlane match repo decryption + SSH read key
- one secret per name listed in `arkana-keys`. The match is case-insensitive, so
  the secret `SENTRYDSN` satisfies the arkana key `SentryDSN`. arkana hard-fails
  when a key declared in the app's `.arkana.yml` has no value, so a missing
  secret fails the build loudly — there are no silent stub builds.

**In-repo build setup** the workflow invokes:
- a fastlane `test` lane and a `stage` lane that outputs `<ipa-name>.ipa`
- `Brewfile` taps `armcknight/tools` and installs its tools **cask** —
  `cask 'armcknight/tools/tools'`, not `brew`, because the tap has no formulae
  (provides `ota-publish`, `inject-git-info`, …). The workflow trusts the tap
  before `brew bundle`.
- ad-hoc signing: an `.adhoc` App ID in the `Matchfile`, an `<APP>_VARIANT`
  xcconfig selector so `stage` can ad-hoc-sign while archiving under `Release`
  (needed because the Sentry cross-project reference only defines Debug/Release),
  and a `match adhoc` profile (`fastlane match adhoc --app_identifier <id>.adhoc`).

## Caller requirements — `macos-cask-release.yml`

**Repo secrets** (passed with `secrets: inherit`):

| Secret | What it is |
|--------|------------|
| `TAP_RELEASE_TOKEN` | Fine-grained PAT, `Contents: read+write` on the tap repo. Creates the release and pushes the cask bump. |
| `MATCH_PASSWORD` | Passphrase the match repo is encrypted with — same secret the iOS repos use. |
| `MATCH_DEPLOY_KEY` | SSH private key with read access to the match repo, same as `ios-ci.yml`. |
| `NOTARY_KEY` | `base64` of an App Store Connect API key `.p8` (Developer role is enough). |
| `NOTARY_KEY_ID` | Key ID of that API key. |
| `NOTARY_ISSUER_ID` | Issuer ID of that API key. |
| … | one secret per name listed in `arkana-keys`, resolved exactly as in `ios-ci.yml`: case-insensitive but not punctuation-insensitive, so the arkana key `SentryDSN` needs a secret named `SENTRYDSN`, not `SENTRY_DSN`. |

The signing identity string is read out of the certificate match installs, so it
is not a separate secret. All six secrets above are **mandatory** — the workflow
fails with a named error rather than shipping an app that Gatekeeper will refuse.

**One-time prerequisite:** the Developer ID cert has to exist in the match repo
before the first release. `match` runs `readonly` here, which reads the encrypted
cert from git and makes no Apple API calls — that is why CI needs no Apple
credentials to sign, and also why it cannot create the cert itself. Create it
once from a Mac:

```
bundle exec fastlane run match type:developer_id platform:macos \
  skip_provisioning_profiles:true team_id:<TEAM_ID> \
  git_url:git@github.com:armcknight/fastlane-match.git
```

`skip_provisioning_profiles` matters: a non-sandboxed hardened-runtime app needs
no provisioning profile, and asking for one would require a registered App ID.

**Caller `permissions`:** `contents: write`. A reusable workflow can only narrow
what the caller grants, so without this the source-repo release step fails.

**In-repo build setup:** a `Brewfile` with the build tools (`xcodegen`,
`xcbeautify`), `gem "fastlane"` in the `Gemfile` (the workflow calls `bundle exec
fastlane run match`; no lanes are needed), `ENABLE_HARDENED_RUNTIME = YES` on the
app target (notarization rejects anything else — the workflow checks the signed
bundle and fails early if it is missing), and `Casks/<cask-name>.rb` already
committed to the tap. The workflow rewrites that cask's `version` and `sha256`
lines; it never creates the file.

### Why the asset goes to the tap repo

A cask URL is fetched by `brew` with no credentials. Release assets on a private
repo need auth, so a private app's zip can't live on its own repo's release. The
tap repo is public, so the workflow creates a `<cask-name>-<version>` release
*there* and attaches the zip to it — same trick `armcknight/tools` uses for its
binaries. This keeps working whether the source repo is private or public, so the
cask never has to change when visibility does. The zip is *also* attached to the
source repo's own release, since that is where people land when the source is
public.

### Why signing is not optional

Homebrew applies the quarantine attribute to every cask download, and a cask has
no way to opt out. An unsigned or ad-hoc-signed `.app` installed by `brew
install --cask` is therefore reported as damaged on first launch. Developer ID
signature + notarization + a stapled ticket is what makes a plain
`brew install --cask` work, offline included.

## Caller examples

`.github/workflows/ci.yml`:

```yaml
name: CI
on:
  pull_request:
permissions:
  contents: read
  checks: write
  pull-requests: write
  id-token: write
jobs:
  ci:
    uses: armcknight/workflows/.github/workflows/ios-ci.yml@1
    with:
      ipa-name: MyApp-staging
      # Key names only — never values. Each name resolves to a same-named repo
      # secret (case-insensitive) inside the reusable workflow.
      arkana-keys: SentryDSN FeedbackEmail
    secrets: inherit
```

`.github/workflows/staging-build.yml`:

```yaml
name: Staging build
on:
  issue_comment:
    types: [created]
permissions:
  contents: read
  checks: write
  pull-requests: write
  id-token: write
jobs:
  # No `if:` here: ios-ci.yml skips every job unless the comment is
  # `/build-staging` on a PR, and checks that the commenter can write to the repo.
  stage:
    uses: armcknight/workflows/.github/workflows/ios-ci.yml@1
    with:
      # The same ios-ci inputs as ci.yml.
      ipa-name: MyApp-staging
      arkana-keys: SentryDSN FeedbackEmail
      pr-number: ${{ github.event.issue.number }}
    secrets: inherit
```

`.github/workflows/refresh-staging-link.yml`:

```yaml
name: Refresh staging link
on:
  issue_comment:
    types: [created]
  workflow_dispatch:
    inputs:
      pr_number: { required: true, type: string }
      run_id: { required: false, type: string }
permissions:
  contents: read
  checks: write
  pull-requests: write
  id-token: write
jobs:
  # No `if:` here: ota-refresh.yml skips its job unless the comment is
  # `/refresh-staging` on a PR, and checks that the commenter can write to the
  # repo. `workflow_dispatch` is already write-gated by GitHub.
  refresh:
    uses: armcknight/workflows/.github/workflows/ota-refresh.yml@1
    with:
      pr-number: ${{ github.event.issue.number || inputs.pr_number }}
      run-id: ${{ inputs.run_id }}
      comment-id: ${{ github.event.comment.id }}
      rebuild-expired: true
    secrets: inherit

  # Runs only when the refresh found the build deleted by the bucket's lifecycle
  # rule. Use the same ios-ci inputs as ci.yml.
  rebuild:
    needs: refresh
    if: needs.refresh.outputs.rebuild == 'true'
    uses: armcknight/workflows/.github/workflows/ios-ci.yml@1
    with:
      ipa-name: MyApp-staging
      arkana-keys: SentryDSN FeedbackEmail
      # The PR's code already ran its tests when it was first built.
      run-tests: false
      # Lets the `/refresh-staging` comment start the build.
      rebuild: true
      pr-number: ${{ github.event.issue.number || inputs.pr_number }}
    secrets: inherit
```

`.github/workflows/stage-cleanup.yml`:

```yaml
name: Stage Cleanup
on:
  pull_request:
    types: [closed]
permissions:
  id-token: write
jobs:
  cleanup:
    uses: armcknight/workflows/.github/workflows/ota-cleanup.yml@1
    secrets: inherit
```

`.github/workflows/release.yml` (macOS app):

```yaml
name: Release
on:
  push:
    tags:
      - '[0-9]+.[0-9]+.[0-9]+'
      - 'v[0-9]+.[0-9]+.[0-9]+'
permissions:
  contents: write
jobs:
  release:
    uses: armcknight/workflows/.github/workflows/macos-cask-release.yml@1
    with:
      scheme: MyApp
      app-name: MyApp
      cask-name: my-app
      version-xcconfig: config/MyApp.xcconfig
      match-git-url: git@github.com:armcknight/fastlane-match.git
      team-id: ABCDE12345
      app-identifier: com.example.MyApp
      arkana-keys: SentryDSN
    secrets: inherit
```

`.github/workflows/ci.yml` and `.github/workflows/deploy.yml` for a Vapor server on Fly:

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  ci:
    uses: armcknight/workflows/.github/workflows/vapor-ci.yml@4
    with:
      swift-image: swift:6.0-noble
```

```yaml
name: Deploy
on:
  workflow_dispatch:
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  deploy:
    uses: armcknight/workflows/.github/workflows/fly-deploy.yml@4
    with:
      app: my-server
      health-check-path: /healthz
      deploy-on: manual   # or merge
    secrets:
      FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

## Notes

- Callers are a mix of private (`mtg`, …) and public (`claude-squad`) repos. This
  repo is public, so its workflows are callable by anyone and the Settings →
  Actions → Access setting no longer applies. That is safe: nothing here is
  secret, and a caller supplies its own `vars` and `secrets`, so it gets its own
  S3 bucket and IAM role, never these. (While this repo was private, Access had to
  be "Accessible from repositories owned by the user account.")
- Installs are **ad-hoc**: a tester's device UDID must be in the `match adhoc`
  provisioning profile.
- `ota-refresh.yml` and `ios-ci.yml` check the command text and the
  commenter's `author_association` themselves on `issue_comment` events, so the
  callers above have no `if:` gate on the comment. The command check is a
  job-level `if:`, so any other comment skips the jobs before a runner starts.
  GitHub still lists a run, with skipped jobs, for each PR comment.
- `issue_comment` and `workflow_run` triggers always run the **default-branch**
  copy of the *caller's* workflow, so `/build-staging` and `/refresh-staging`
  only work once the caller's workflows are on its default branch.
- Pin callers to the moving major tag, `@1`, not to `@main`. `@main` gets a
  breaking change the moment it merges, with no release note to warn you. See
  [Versioning and pinning](#versioning-and-pinning).
