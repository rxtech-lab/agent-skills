# Secrets Management

## Table of Contents

- [Secret Inventory](#secret-inventory)
- [Encoding and Decoding](#encoding-and-decoding)
- [Adding or Rotating Secrets](#adding-or-rotating-secrets)

## Secret Inventory

Both CI systems use the same secrets, encoded in base64:

| Secret | GitHub Actions | Xcode Cloud | Contents |
|--------|---------------|-------------|----------|
| `SECRETS_XCCONFIG_BASE64` | GitHub Secret | Environment Variable | OAuth client IDs (`AUTH_CLIENT_ID_DEV`, `AUTH_CLIENT_ID_PROD`) |
| `RXSTORAGE_TESTING_SECRETS` | GitHub Secret | Environment Variable | Test credentials for E2E tests |
| `ADMIN_ENV_BASE64` | GitHub Secret | N/A | Backend `.env` (database URL, auth config) |
| `RELEASE_TOKEN` | GitHub Secret | N/A | GitHub PAT for creating releases |

## Encoding and Decoding

Secrets are base64-encoded for storage and decoded identically in both systems:

```bash
# Encode a file for storage
base64 -i Secrets.xcconfig | pbcopy

# Decode in CI (used by both ios-setup.yml and ci_post_clone.sh)
echo "$SECRETS_XCCONFIG_BASE64" | base64 --decode > Secrets.xcconfig
```

## Adding or Rotating Secrets

### GitHub Actions secrets

1. Go to repo Settings → Secrets and variables → Actions
2. Update or add the secret value (base64-encoded)
3. All workflows using `ios-setup.yml` automatically pick up the change

### Xcode Cloud environment variables

1. Open Xcode → Xcode Cloud settings for the workflow
2. Update the environment variable value (base64-encoded)
3. Next Xcode Cloud build uses the updated value

### RELEASE_TOKEN

The `RELEASE_TOKEN` is a GitHub PAT with `contents: write` permission, used by the `create-release.yaml` workflow to push tags and create releases. Rotate by generating a new PAT and updating the GitHub Actions secret.
