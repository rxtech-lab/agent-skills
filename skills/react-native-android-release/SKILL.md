---
name: react-native-android-release
description: Set up and manage React Native (Expo/EAS) Android releases via GitHub Actions. Use when the user needs to (1) configure the Android release pipeline (local EAS build, version bump, Google Play submit), (2) create or modify the GitHub Actions release workflow (android-release.yml), (3) set up or debug eas.json build/submit profiles, (4) configure the Google Play service-account credential as a base64 secret, (5) wire EXPO_TOKEN and EAS-managed signing keystore, (6) bump app.json version from a release tag with EAS remote versionCode auto-increment, (7) publish an AAB to the Google Play internal track via EAS Submit, or (8) fall back to a bare React Native Gradle + Fastlane path when not using Expo managed workflow.
---

# React Native Android Release

Android app release pipeline for **Expo managed workflow + EAS**: **GitHub Actions** builds the AAB locally on the runner (`eas build --local`), bumps the version from the release tag, and publishes to the Google Play **internal** track via **EAS Submit**.

This is the Android sibling of the `sparkle-github-release` (macOS) and `ios-auto-release` (iOS) skills — same "on release → bump version → build artifact → publish" flow, gated so that every `push` builds the artifact (smoke test) but only a published `release` submits to the store.

> **Primary path: Expo managed workflow.** No `android/` directory, no `build.gradle`, no `signingConfigs`, no Fastlane committed. The Android project, Metro bundling, and `gradle bundleRelease` all happen *inside* EAS Build. For bare React Native (committed `android/`), see the documented [Gradle + Fastlane fallback](references/bare-rn-fallback.md).

## Architecture

```
GitHub Release (vX.Y.Z, type: created/published)
         │
         ▼
  GitHub Actions (ubuntu-latest)
         │
         ├──► setup-java 17 (temurin) + Node 20 + bun + eas-cli + Android SDK
         │
         ├──► Set version from tag  → jq rewrites app.json .expo.version
         │
         ├──► eas build --local     → ./build-android.aab  (gradle bundleRelease inside EAS)
         │
         ├──► Decode service account → ./google-service-account.json (from base64 secret)
         │
         └──► eas submit            → Google Play INTERNAL track  [release events only]

  push event (any branch) ──► builds the AAB only (smoke test), no submit
```

## Release Workflow

### Creating a release

1. Ensure GitHub secrets are configured → see [secrets.md](references/secrets.md) (`EXPO_TOKEN`, `GOOGLE_SERVICE_ACCOUNT_B64`)
2. Ensure `eas.json` has a `production` build profile (remote versionCode auto-increment) and an `internal` submit profile → see [eas-config.md](references/eas-config.md)
3. Create a GitHub Release with a semver tag (e.g. `v1.2.3`)
4. The workflow rewrites `app.json` version from the tag, builds the AAB locally, decodes the service account, and submits to the Play internal track
5. The build appears in Google Play Console → Internal testing; promote to closed/open/production from there

### Pipeline stages

| Stage | Tool | Output |
|-------|------|--------|
| Version bump | `jq` on `app.json` | `.expo.version` = tag (e.g. `1.2.3`) |
| Build | `eas build --platform android --profile production --local` | `./build-android.aab` |
| Decode creds | `base64 -d` of `GOOGLE_SERVICE_ACCOUNT_B64` | `./google-service-account.json` |
| Submit | `eas submit --platform android --profile internal` | Upload to Play **internal** track |

### Version identifiers

| Field | Source | Owner | Example |
|-------|--------|-------|---------|
| `version` (versionName) | Release tag (`vX.Y.Z` → `X.Y.Z`) | Git tag, written to `app.json` at build time | `1.2.3` |
| `versionCode` | `appVersionSource: "remote"` + `autoIncrement: true` | EAS (monotonic, server-side) | `42` |

The human-facing versionName comes from the tag; EAS owns the monotonic Android `versionCode`. Versions are not committed to the repo — `app.json` is rewritten only on the CI runner. See [version-bump.md](references/version-bump.md).

## Key commands

```bash
# Build the AAB locally on the runner (no cloud minutes)
cd mobile
eas build --platform android --profile production --local --non-interactive --output ./build-android.aab

# Bump version from the release tag
VERSION="${GITHUB_REF_NAME#v}"   # v1.2.3 -> 1.2.3
cat <<< "$(jq --arg v "$VERSION" '.expo.version = $v' app.json)" > app.json

# Decode the Google Play service account (never commit this file)
echo "$GOOGLE_SERVICE_ACCOUNT_B64" | base64 -d > ./google-service-account.json

# Submit the AAB to the Google Play internal track
eas submit --platform android --profile internal --path ./build-android.aab --non-interactive
```

## File Reference

| File | Purpose |
|------|---------|
| `.github/workflows/android-release.yml` | Full release pipeline (build on push, submit on release) — template in [templates/android-release.yml](templates/android-release.yml) |
| `eas.json` | EAS build + submit profiles (`production` build, `internal` submit) |
| `app.json` | Expo config; `.expo.version` rewritten from the tag at build time |
| `scripts/set-version.sh` | Stamp `app.json` version from the release tag (jq) |
| `scripts/decode-service-account.sh` | Decode `GOOGLE_SERVICE_ACCOUNT_B64` → `google-service-account.json` |
| `google-service-account.json` | Google Play SA key — **decoded at runtime, NEVER committed** (gitignore it) |

## Required secrets

| Secret | Description |
|--------|-------------|
| `EXPO_TOKEN` | Expo access token; authenticates `eas build`/`eas submit` and the EAS-managed keystore |
| `GOOGLE_SERVICE_ACCOUNT_B64` | Base64-encoded Google Play Developer API service-account JSON |

See [secrets.md](references/secrets.md) for how to generate and encode each.

## Credential hygiene (footgun)

**Never commit `google-service-account.json`.** It contains a plaintext `private_key`. Store it base64-encoded as the `GOOGLE_SERVICE_ACCOUNT_B64` GitHub secret, decode it to a file at runtime, and point `serviceAccountKeyPath` at the decoded file. Add `google-service-account.json` to `.gitignore`. See [signing-and-credentials.md](references/signing-and-credentials.md).

## References

- **GitHub Actions workflow** (trigger, job, push-vs-release gating, runner prereqs): [github-actions.md](references/github-actions.md)
- **eas.json profiles** (production build, remote versionCode, internal submit profile): [eas-config.md](references/eas-config.md)
- **Signing & credentials** (EAS-managed keystore, EXPO_TOKEN, service-account base64 flow, footgun): [signing-and-credentials.md](references/signing-and-credentials.md)
- **Version bumping** (app.json jq rewrite, remote versionCode auto-increment): [version-bump.md](references/version-bump.md)
- **Secrets management** (required secrets, how to generate and encode each): [secrets.md](references/secrets.md)
- **Bare RN fallback** (committed `android/`, Gradle Play Publisher / Fastlane supply): [bare-rn-fallback.md](references/bare-rn-fallback.md)
