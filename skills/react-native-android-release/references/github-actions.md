# GitHub Actions Workflow

## Table of Contents

- [Trigger](#trigger)
- [Runner prerequisites](#runner-prerequisites)
- [Job: Android](#job-android)
- [Push vs release gating](#push-vs-release-gating)
- [The build command](#the-build-command)
- [The submit command](#the-submit-command)

## Trigger

**File:** `.github/workflows/android-release.yml`

The workflow responds to two event types:

| Event | Behavior |
|-------|----------|
| `push` (any branch) | Build the AAB locally as a smoke test — no version bump, no submit |
| `release` (types: `created`, `published`) | Full pipeline — bump version from tag, build, decode credentials, submit to Play internal track |

This mirrors the `sparkle-github-release` macOS skill, where `push` builds only and `release` runs the full signed/published pipeline.

```yaml
on:
  release:
    types: [created, published]
  push:
```

## Runner prerequisites

`runs-on: ubuntu-latest` (consider a larger runner — local Android builds are heavy: `gradle bundleRelease` runs inside EAS). Required tooling, installed via setup actions:

| Tool | Action / command | Why |
|------|------------------|-----|
| JDK 17 (temurin) | `actions/setup-java@v4` | Android Gradle build |
| Node 20 | `actions/setup-node@v4` | Metro bundler, EAS CLI |
| bun | `oven-sh/setup-bun@v2` | install JS deps (`bun install`); npm/yarn also fine |
| eas-cli | `npm install -g eas-cli` | drives build + submit |
| Android SDK | provided by `eas build --local` / ubuntu image | compile + bundle |

`actions/setup-java@v4` and the ubuntu image supply the Android SDK that `eas build --local` needs; EAS downloads any missing platform/build-tools.

## Job: Android

Steps in order (working directory `mobile/`, adjust if the Expo app is at the repo root):

1. **Checkout** — `actions/checkout@v6`
2. **Setup Java 17** (temurin)
3. **Setup Node 20**
4. **Setup bun**
5. **Install eas-cli** — `npm install -g eas-cli`
6. **Install dependencies** — `bun install`
7. **Set version from release tag** *(release only)* — `jq` rewrites `app.json` `.expo.version` from `GITHUB_REF_NAME` (`v1.2.3` → `1.2.3`)
8. **Build Android AAB** — `eas build --local` → `./build-android.aab` (needs `EXPO_TOKEN`)
9. **Decode Google Play service account** *(release only)* — `base64 -d` of `GOOGLE_SERVICE_ACCOUNT_B64` → `./google-service-account.json`
10. **Submit to Google Play internal track** *(release only)* — `eas submit` (needs `EXPO_TOKEN`)

## Push vs release gating

Steps 7, 9, and 10 are guarded with `if: github.event_name == 'release'`. The build step (8) runs on **every** event, so each push validates that the AAB still builds while only a published release submits to the store.

> The reference project wrote this as `if: github.event_name != 'push'`. With only `release` + `push` triggers the two forms are equivalent; `== 'release'` is preferred for clarity and stays correct if more triggers are added later.

## The build command

```bash
cd mobile
eas build --platform android --profile production --local --non-interactive --output ./build-android.aab
```

| Flag | Purpose |
|------|---------|
| `--platform android` | Build the Android target |
| `--profile production` | Use the `production` build profile in `eas.json` (remote versionCode auto-increment) |
| `--local` | Build on the CI runner — no EAS cloud build minutes |
| `--non-interactive` | Fail instead of prompting (CI) |
| `--output ./build-android.aab` | Write the AAB to a known path for the submit step |

`--local` means the Android project generation (prebuild), Metro JS bundling, and `gradle bundleRelease` all happen inside EAS on the runner. Authentication (and the EAS-managed keystore) is provided by `EXPO_TOKEN`.

## The submit command

```bash
eas submit --platform android --profile internal --path ./build-android.aab --non-interactive
```

`--profile internal` resolves to the `submit.internal.android` block in `eas.json`, which sets `track: "internal"` and `serviceAccountKeyPath: "./google-service-account.json"`. EAS Submit wraps the **Google Play Developer API** directly — not Fastlane `supply`, not the Gradle Play Publisher. See [eas-config.md](eas-config.md).
