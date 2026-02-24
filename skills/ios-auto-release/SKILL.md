---
name: ios-auto-release
description: Manage the two-stage iOS release pipeline using GitHub Actions for CI/semantic versioning and Xcode Cloud for App Store distribution. Use when the user needs to (1) trigger a new iOS release, (2) understand or modify CI workflows (ios-ci.yml, ios-setup.yml, create-release.yaml), (3) debug version bumping or Xcode Cloud builds, (4) update the ci_post_clone.sh script, (5) configure or rotate CI secrets, (6) understand conventional commit conventions for version bumps, or (7) troubleshoot failed releases or TestFlight submissions.
---

# iOS Auto Release

Two-stage release pipeline: **GitHub Actions** for CI + semantic versioning, **Xcode Cloud** for App Store distribution.

## Architecture

```
Push to main
     │
     ▼
GitHub Actions ──► Build + Test (5 parallel jobs)
     │
     ▼
Manual Trigger ──► Semantic Release ──► Analyzes commits
                        │
                        ▼
                  Creates git tag (v1.2.3)
                  Creates GitHub Release
                        │
                        ▼
              Xcode Cloud detects tag ──► ci_post_clone.sh
                        │                     │
                        │              Extracts version from CI_TAG
                        │              Stamps MARKETING_VERSION
                        │              Sets CURRENT_PROJECT_VERSION
                        │                     │
                        ▼                     ▼
                  Xcode Cloud builds ──► TestFlight / App Store
```

## Release Workflow

### Creating a release

1. Ensure all commits on `main` follow conventional commit format
2. Go to GitHub Actions → **Create a new release** workflow → **Run workflow** on `main`
3. Semantic Release analyzes commits since last tag and determines version bump
4. If releasable commits exist → creates git tag `vX.Y.Z` + GitHub Release with auto-generated notes
5. Xcode Cloud detects the tag → runs `ci_post_clone.sh` → builds and uploads to TestFlight

### Conventional commit conventions

| Prefix | Bump | Example |
|--------|------|---------|
| `fix:` | Patch (1.0.0 → 1.0.1) | `fix: resolve crash on item delete` |
| `feat:` | Minor (1.0.0 → 1.1.0) | `feat: add QR code scanning` |
| `feat!:` or `BREAKING CHANGE:` | Major (1.0.0 → 2.0.0) | `feat!: redesign API response format` |
| `chore:`, `docs:`, `ci:` | No release | `chore: update dependencies` |

### Version identifiers

| Field | Build Setting | Example | Purpose |
|-------|---------------|---------|---------|
| Version | `MARKETING_VERSION` | `1.2.3` | User-facing App Store version |
| Build | `CURRENT_PROJECT_VERSION` | `42` | Internal build number, auto-incremented by Xcode Cloud |

Default values in project file (`1.0` / `5`) are overwritten at build time — versions are never committed to the repo.

## File Reference

| File | Purpose |
|------|---------|
| `.github/workflows/ios-ci.yml` | CI on every push: 5 parallel build/test jobs |
| `.github/workflows/ios-setup.yml` | Reusable setup (secrets, tooling, backend, OpenAPI) |
| `.github/workflows/create-release.yaml` | Manual semantic release trigger |
| `.releaserc` | Semantic release plugin config |
| `RxStorage/ci_scripts/ci_post_clone.sh` | Xcode Cloud version bumping + environment setup |
| `scripts/ios-build.sh` | iOS simulator build |
| `scripts/ios-test.sh` | Swift Package unit tests |
| `scripts/ios-ui-test.sh` | UI tests with backend |
| `scripts/macos-build.sh` | macOS build |
| `scripts/ios-update-openapi.sh` | OpenAPI client regeneration |
| `scripts/decode-env-secrets.sh` | Decode base64 test secrets |

## References

- **GitHub Actions CI** (workflow details, jobs, reusable setup): [github-actions.md](references/github-actions.md)
- **Xcode Cloud** (post-clone script, version bumping, environment variables): [xcode-cloud.md](references/xcode-cloud.md)
- **Secrets management** (encoding, decoding, rotation for both CI systems): [secrets.md](references/secrets.md)
