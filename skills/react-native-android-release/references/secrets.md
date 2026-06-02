# Secrets Management

## Table of Contents

- [Required Secrets](#required-secrets)
- [How to Generate Each Secret](#how-to-generate-each-secret)
- [Adding or Rotating Secrets](#adding-or-rotating-secrets)

## Required Secrets

| Secret | Description |
|--------|-------------|
| `EXPO_TOKEN` | Expo access token — authenticates `eas build`/`eas submit` and unlocks the EAS-managed Android keystore |
| `GOOGLE_SERVICE_ACCOUNT_B64` | Base64-encoded Google Play Developer API service-account JSON |

Only these two secrets are needed for the Expo managed path — EAS holds the signing keystore on its servers, so there is no certificate/keystore secret to manage (unlike the macOS `sparkle-github-release` skill, which needs `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, etc.).

## How to Generate Each Secret

### Expo Access Token (`EXPO_TOKEN`)

1. Sign in at [expo.dev](https://expo.dev)
2. Account → **Access Tokens** → **Create token**
3. Prefer a token scoped to the project/organization rather than account-wide
4. Store the value as the `EXPO_TOKEN` GitHub secret

This token both authenticates the build/submit CLI calls and authorizes fetching the EAS-managed keystore. See [signing-and-credentials.md](signing-and-credentials.md).

### Google Play Service Account (`GOOGLE_SERVICE_ACCOUNT_B64`)

1. Google Play Console → **Setup → API access** → link or create a Google Cloud project
2. Create a service account in Google Cloud, then in the Play Console grant it **release** permission for the app
3. Create and download a JSON key for the service account
4. Base64-encode it (do this locally — never commit the JSON):

   ```bash
   base64 -i google-service-account.json | pbcopy   # macOS
   # base64 -w0 google-service-account.json          # Linux (no line wrap)
   ```

5. Store the encoded value as the `GOOGLE_SERVICE_ACCOUNT_B64` GitHub secret

> **Footgun:** the JSON contains a plaintext `private_key`. Never commit it; always go through this base64-secret flow and decode at runtime. Add `google-service-account.json` to `.gitignore`. See [signing-and-credentials.md](signing-and-credentials.md).

## Adding or Rotating Secrets

1. Go to the repository **Settings → Secrets and variables → Actions**
2. Update or add the secret value
3. For `GOOGLE_SERVICE_ACCOUNT_B64`, re-encode the updated JSON before pasting
4. To rotate a leaked service-account key: delete it in Google Cloud, create a new JSON key, re-encode, and update the secret
5. To rotate `EXPO_TOKEN`: revoke the old token at expo.dev and create a new one
6. The next workflow run automatically uses the updated secret
