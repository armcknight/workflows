# armcknight/workflows

Reusable GitHub Actions workflows shared across armcknight iOS apps. Today this
is the **staging OTA** pipeline: on every PR, run tests, then build an ad-hoc
IPA and publish a presigned [`itms-services`](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices)
over-the-air install link to a private S3 bucket, commented on the PR.

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
| `ios-ci.yml` | `pull_request` | `test` job, then `stage` job (`needs: test`): build the ad-hoc IPA, upload to S3, comment a 12 h install link. |
| `ota-refresh.yml` | `issue_comment` `/refresh-staging` or `workflow_dispatch` | Re-sign the link for a PR's latest (or given) build — no rebuild. |
| `ota-cleanup.yml` | `pull_request: closed` | Delete the PR's S3 prefix. |

S3 layout (one bucket, namespaced per project): `s3://<bucket>/<repo>/pr-<n>/run-<id>/`.

## Caller requirements

**Repo variables** (read from the caller automatically — `vars` propagate into
reusable workflows; only secrets need `inherit`):
- `AWS_ROLE_ARN` — IAM role assumed via GitHub OIDC (no long-lived keys)
- `AWS_REGION`
- `S3_BUCKET`

**Repo secrets** (passed with `secrets: inherit`):
- `MATCH_PASSWORD`, `MATCH_DEPLOY_KEY` — fastlane match repo decryption + SSH read key

**In-repo build setup** the workflow invokes:
- a fastlane `test` lane and a `stage` lane that outputs `<ipa-name>.ipa`
- `Brewfile` taps `armcknight/tools` (provides `ota-publish`, `xcodegen`, …)
- ad-hoc signing: an `.adhoc` App ID in the `Matchfile`, an `<APP>_VARIANT`
  xcconfig selector so `stage` can ad-hoc-sign while archiving under `Release`
  (needed because the Sentry cross-project reference only defines Debug/Release),
  and a `match adhoc` profile (`fastlane match adhoc --app_identifier <id>.adhoc`).

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
    uses: armcknight/workflows/.github/workflows/ios-ci.yml@main
    with:
      ipa-name: MyApp-staging
      arkana-env: |
        SentryDSN=https://stub@sentry.io/0
        FeedbackEmail=stub@example.com
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
  pull-requests: write
  id-token: write
jobs:
  refresh:
    if: >
      github.event_name == 'workflow_dispatch' ||
      (github.event.issue.pull_request && startsWith(github.event.comment.body, '/refresh-staging'))
    uses: armcknight/workflows/.github/workflows/ota-refresh.yml@main
    with:
      pr-number: ${{ github.event.issue.number || inputs.pr_number }}
      run-id: ${{ inputs.run_id }}
      comment-id: ${{ github.event.comment.id }}
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
    uses: armcknight/workflows/.github/workflows/ota-cleanup.yml@main
    secrets: inherit
```

## Notes

- These are referenced from private repos, so this repo's
  Settings → Actions → Access is set to "Accessible from repositories owned by
  the user account."
- Installs are **ad-hoc**: a tester's device UDID must be in the `match adhoc`
  provisioning profile.
- `issue_comment` and `workflow_run` triggers always run the **default-branch**
  copy of the *caller's* workflow, so `/refresh-staging` only works once the
  caller's workflow is on its default branch.
- Pin callers to `@main` or cut a tag (e.g. `@v1`) here and reference that.
