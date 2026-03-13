# Secrets Management

## Table of Contents

- [Required Secrets](#required-secrets)
- [How to Generate Each Secret](#how-to-generate-each-secret)
- [Adding or Rotating Secrets](#adding-or-rotating-secrets)

## Required Secrets

| Secret | Description |
|--------|-------------|
| `BUILD_CERTIFICATE_BASE64` | Developer ID Application certificate (.p12), base64-encoded |
| `P12_PASSWORD` | Password for the .p12 certificate file |
| `PROVISIONING_PROFILE_BASE64` | Developer ID provisioning profile, base64-encoded |
| `SIGNING_CERTIFICATE_NAME` | Full signing identity, e.g. `"Developer ID Application: Your Name (TEAMID)"` |
| `APPLE_ID` | Apple ID email for notarization |
| `APPLE_ID_PWD` | App-specific password for notarization |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `SPARKLE_KEY` | Sparkle EdDSA private key (from `generate_keys`) |
| `SECRETS_XCCONFIG_BASE64` | Xcode build secrets config, base64-encoded |
| `ADMIN_ENV_BASE64` | Backend .env for OpenAPI spec generation |

## How to Generate Each Secret

### Developer ID Certificate (`BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`)

1. Go to Apple Developer Portal → Certificates → + → Developer ID Application
2. Generate a CSR from Keychain Access, upload it, and download the certificate
3. Import the certificate to Keychain Access
4. Export as `.p12` file with a password
5. Encode for GitHub: `base64 -i cert.p12 | pbcopy` → store as `BUILD_CERTIFICATE_BASE64`
6. Store the .p12 password as `P12_PASSWORD`

### Signing Identity (`SIGNING_CERTIFICATE_NAME`)

After importing the certificate, find the full identity name in Keychain Access. It follows the format:

```
Developer ID Application: Your Name (TEAMID)
```

Store this exact string as the `SIGNING_CERTIFICATE_NAME` secret.

### Provisioning Profile (`PROVISIONING_PROFILE_BASE64`)

1. Go to Apple Developer Portal → Profiles → + → Developer ID Application
2. Select your App ID (e.g. `rxlab.lindaAssistant`) and the Developer ID certificate created above
3. Download the `.provisionprofile` file
4. Encode for GitHub: `base64 -i profile.provisionprofile | pbcopy` → store as `PROVISIONING_PROFILE_BASE64`

### Sparkle EdDSA Keys (`SPARKLE_KEY`)

```bash
# From the Sparkle tools (in bin/ or from Sparkle release)
./bin/generate_keys
# Outputs:
#   Private key → save as SPARKLE_KEY secret
#   Public key → set as SUPublicEDKey in Info.plist
```

The private key is used by CI to sign appcast entries. The public key is embedded in the app to verify updates.

### App-Specific Password (`APPLE_ID_PWD`)

1. Go to [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → App-Specific Passwords
2. Generate a new password labeled "notarytool"
3. Store as `APPLE_ID_PWD`

### Apple Team ID (`APPLE_TEAM_ID`)

Find your Team ID at [developer.apple.com/account](https://developer.apple.com/account) → Membership Details.

### Xcode Secrets Config (`SECRETS_XCCONFIG_BASE64`)

Base64-encode your `Secrets.xcconfig` file containing build-time secrets (e.g. OAuth client IDs):

```bash
base64 -i Secrets.xcconfig | pbcopy
```

### Backend Environment (`ADMIN_ENV_BASE64`)

Base64-encode the backend `.env` file used for OpenAPI spec generation during CI:

```bash
base64 -i admin/.env | pbcopy
```

## Adding or Rotating Secrets

1. Go to the repository Settings → Secrets and variables → Actions
2. Update or add the secret value
3. For base64-encoded secrets, re-encode the updated file before pasting
4. The next workflow run will automatically use the updated secret
