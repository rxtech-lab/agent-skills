# eas.json Profiles

`eas.json` lives at the root of the Expo app (next to `app.json` / `package.json`). It defines **build** profiles (consumed by `eas build`) and **submit** profiles (consumed by `eas submit`).

## Table of Contents

- [Full example](#full-example)
- [Build profile: production](#build-profile-production)
- [Submit profile: internal](#submit-profile-internal)
- [Why remote versionCode](#why-remote-versioncode)

## Full example

```json
{
  "cli": {
    "version": ">= 12.0.0",
    "appVersionSource": "remote"
  },
  "build": {
    "production": {
      "android": {
        "buildType": "app-bundle",
        "autoIncrement": true
      }
    }
  },
  "submit": {
    "internal": {
      "android": {
        "serviceAccountKeyPath": "./google-service-account.json",
        "track": "internal"
      }
    }
  }
}
```

## Build profile: production

The CI workflow runs `eas build --profile production`. Key fields under `build.production.android`:

| Field | Value | Purpose |
|-------|-------|---------|
| `buildType` | `app-bundle` | Produce an `.aab` (required for Play uploads), not an `.apk` |
| `autoIncrement` | `true` | EAS bumps the Android `versionCode` on each build |

`autoIncrement` only works in tandem with `appVersionSource: "remote"` (set under `cli`) — that tells EAS to track and increment `versionCode` on its servers rather than reading it from `app.json`. See [Why remote versionCode](#why-remote-versioncode).

## Submit profile: internal

The CI workflow runs `eas submit --profile internal`. Fields under `submit.internal.android`:

| Field | Value | Purpose |
|-------|-------|---------|
| `track` | `internal` | Publish to the Google Play **internal testing** track |
| `serviceAccountKeyPath` | `./google-service-account.json` | Path to the Play Developer API key, decoded at runtime from a base64 secret |

`track` accepts `internal`, `alpha`, `beta`, or `production`. Start at `internal` and promote within the Play Console; never auto-publish straight to `production` from CI without a rollout gate.

`serviceAccountKeyPath` points at a file that is **decoded at runtime** from the `GOOGLE_SERVICE_ACCOUNT_B64` secret — the JSON is never committed. See [signing-and-credentials.md](signing-and-credentials.md).

## Why remote versionCode

Google Play rejects an AAB whose `versionCode` is not strictly greater than the last upload on that track. Two ways to manage it:

| Source | Behavior |
|--------|----------|
| `appVersionSource: "local"` | `versionCode` read from `app.json` — you must hand-bump and commit it every release (error-prone, merge conflicts) |
| `appVersionSource: "remote"` | EAS tracks the last `versionCode` server-side and `autoIncrement` bumps it monotonically — nothing to commit |

This skill uses **remote** so that:

- the **versionName** (human-facing) is driven by the git tag, written into `app.json` at build time (see [version-bump.md](version-bump.md)), and
- the **versionCode** (Play's monotonic integer) is owned entirely by EAS.

The two never fight, and no version number is committed to the repo.
