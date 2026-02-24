# GitHub Actions CI

## Table of Contents

- [Continuous Integration (ios-ci.yml)](#continuous-integration)
- [Reusable Setup Workflow (ios-setup.yml)](#reusable-setup-workflow)
- [Create Release Workflow (create-release.yaml)](#create-release-workflow)
- [Semantic Release Configuration (.releaserc)](#semantic-release-configuration)

## Continuous Integration

**File:** `.github/workflows/ios-ci.yml`

Runs on every push to any branch. Five parallel jobs via the reusable `ios-setup.yml`:

| Job | Script | Runner | Purpose |
|-----|--------|--------|---------|
| Build iOS App | `ios-build.sh` | `macos-latest` | Verify iOS simulator build |
| Build macOS App | `macos-build.sh` | `macos-26` | Verify macOS build |
| Run Tests | `ios-test.sh` | `macos-26` | Swift Package unit tests |
| Build App Clips | `ios-build.sh` | `macos-latest` | Verify App Clips target |
| Run UI Tests | `ios-ui-test.sh` | `self-hosted` | End-to-end UI tests |

Concurrency groups cancel in-progress builds when new commits push to the same branch:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

## Reusable Setup Workflow

**File:** `.github/workflows/ios-setup.yml`

A `workflow_call` reusable workflow shared by all CI jobs. Steps in order:

1. Checkout code
2. Setup tooling — Bun (latest), Xcode (latest-stable), xcbeautify
3. Decode secrets — write `Secrets.xcconfig`, `RxStorage/.env`, `admin/.env` from base64 GitHub Secrets
4. Cache Xcode derived data keyed on `Package.swift` hash
5. Start backend — install admin dependencies, run `bun dev:e2e` in background
6. Generate OpenAPI client — run `./scripts/ios-update-openapi.sh`
7. Execute job-specific script (`ios-build.sh`, `ios-test.sh`, etc.)
8. Upload artifacts — build logs, backend logs, `.xcresult` test results, screenshots on failure

## Create Release Workflow

**File:** `.github/workflows/create-release.yaml`

```yaml
on: workflow_dispatch
name: Create a new release

jobs:
  create-release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    if: ${{ (github.event.pusher.name != 'github action') && (github.ref == 'refs/heads/main') }}
    steps:
      - name: Checkout
        uses: actions/checkout@v6
      - name: Semantic Release
        uses: cycjimmy/semantic-release-action@v6
        env:
          GITHUB_TOKEN: ${{ secrets.RELEASE_TOKEN }}
        with:
          branch: main
```

Key details:
- **Manually triggered** (`workflow_dispatch`) — not automatic on push
- **Only runs on `main`** — the `if` condition enforces this
- **Guard against loops** — skips if the pusher is `github action`
- **Uses `RELEASE_TOKEN`** — a GitHub PAT with `contents: write` permission

## Semantic Release Configuration

**File:** `.releaserc`

```json
{
    "plugins": [
        "@semantic-release/commit-analyzer",
        "@semantic-release/release-notes-generator",
        "@semantic-release/github"
    ]
}
```

| Plugin | Purpose |
|--------|---------|
| `commit-analyzer` | Parse conventional commits to determine version bump type |
| `release-notes-generator` | Auto-generate changelog from commit messages |
| `github` | Create GitHub Release with tag and release notes |
