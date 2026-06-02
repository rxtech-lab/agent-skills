# Signing & Credentials

Two independent credential systems are involved. Keep them separate:

| Credential | Used for | Provided to CI as |
|------------|----------|-------------------|
| **Android upload keystore** | Signing the AAB | EAS-managed (no committed keystore), unlocked by `EXPO_TOKEN` |
| **Google Play service account** | Uploading the AAB to Play | `GOOGLE_SERVICE_ACCOUNT_B64` → decoded file |

## Table of Contents

- [EAS-managed keystore](#eas-managed-keystore)
- [EXPO_TOKEN](#expo_token)
- [Service-account base64 flow](#service-account-base64-flow)
- [The footgun: never commit the SA JSON](#the-footgun-never-commit-the-sa-json)

## EAS-managed keystore

With the Expo managed workflow, **do not commit a keystore or `signingConfigs`**. EAS generates and stores the Android upload keystore on its servers the first time you build for Android. Subsequent `eas build` runs (including `--local` in CI) fetch and use it automatically, authenticated by `EXPO_TOKEN`.

To create or inspect the keystore interactively (once, from a dev machine):

```bash
eas credentials --platform android
```

This lets you view, download (for backup), or rotate the keystore. For CI you generally never touch it — the first build creates it and every later build reuses it. Back up the keystore: losing it means you cannot ship updates to an existing Play listing.

> **Bare React Native fallback:** if the project commits its own `android/` with `signingConfigs` and a `*.keystore`, EAS is not signing — see [bare-rn-fallback.md](bare-rn-fallback.md) for the keystore-as-base64-secret + Gradle approach.

## EXPO_TOKEN

A non-interactive Expo access token. It authenticates `eas build` and `eas submit` and authorizes fetching the EAS-managed keystore.

1. Create at [expo.dev](https://expo.dev) → Account → **Access Tokens** → Create
2. Store as the `EXPO_TOKEN` GitHub secret
3. The workflow passes it via `env: { EXPO_TOKEN: ${{ secrets.EXPO_TOKEN }} }` on the build and submit steps

Prefer a token scoped to the specific project/organization over a personal account-wide token.

## Service-account base64 flow

EAS Submit talks to the Google Play Developer API using a Google Cloud service account that has been granted access in the Play Console.

**Generate the service account:**

1. Google Play Console → **Setup → API access** → link / create a Google Cloud project
2. Create a service account in Google Cloud → grant it a role, then in Play Console grant it **release** permissions for your app
3. Create a JSON key for the service account and download it

**Encode and store (do this locally, never commit the file):**

```bash
base64 -i google-service-account.json | pbcopy   # macOS
# base64 -w0 google-service-account.json          # Linux
```

Store the result as the `GOOGLE_SERVICE_ACCOUNT_B64` GitHub secret.

**Decode at runtime (in CI):**

```bash
echo "$GOOGLE_SERVICE_ACCOUNT_B64" | base64 -d > ./google-service-account.json
```

`eas.json`'s `submit.internal.android.serviceAccountKeyPath` then points at `./google-service-account.json`. The helper `scripts/decode-service-account.sh` does this with a validity check.

## The footgun: never commit the SA JSON

The service-account JSON contains a **plaintext `private_key`**. A reference project committed `google-service-account.json` directly with the live private key in the repo — a credential leak that grants upload access to the Play listing to anyone who can read the repo or its history.

Standardize on the base64-secret flow instead:

- ✅ Store the JSON as the base64 secret `GOOGLE_SERVICE_ACCOUNT_B64`
- ✅ Decode to a file at runtime, reference via `serviceAccountKeyPath`
- ✅ Add `google-service-account.json` (and `*.keystore`, `*.jks`) to `.gitignore`
- ❌ Never commit the JSON, even "temporarily" — it persists in git history

```gitignore
# Android / Play credentials — never commit
google-service-account.json
*.keystore
*.jks
```

If an SA key was ever committed, rotate it: delete the leaked key in Google Cloud and issue a new one.
