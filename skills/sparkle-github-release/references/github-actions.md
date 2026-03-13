# GitHub Actions Workflow

## Table of Contents

- [Trigger](#trigger)
- [Job 1: Build (macOS)](#job-1-build-macos)
- [Job 2: Deploy (Ubuntu)](#job-2-deploy-ubuntu)
- [Archive Command](#archive-command)
- [DNS Setup](#dns-setup)

## Trigger

**File:** `.github/workflows/macos-release.yml`

The workflow responds to two event types:

| Event | Behavior |
|-------|----------|
| `push` | Build only — no signing, notarization skipped (`SKIP_NOTARIZE=true`) |
| `release` (type: `released`) | Full pipeline — signing, notarization, appcast generation, and deploy |

## Job 1: Build (macOS)

**Runner:** `self-hosted` (macOS)

Steps in order:

1. **Checkout** repository
2. **Setup tooling** — Bun, Xcode (latest-stable), Python
3. **Decode secrets** — write `Secrets.xcconfig` and `.env` from base64 GitHub Secrets
4. **Start backend** — install dependencies, run backend + worker servers
5. **Generate OpenAPI spec** — from running backend
6. **Install CI tools** — `create-dmg`, `xcpretty`, `markdown` (Python package)
7. **Import certificate** — decode `.p12` from `BUILD_CERTIFICATE_BASE64`, import to temporary keychain
8. **Import provisioning profile** — decode from `PROVISIONING_PROFILE_BASE64`, copy to `~/Library/MobileDevice/Provisioning Profiles/`
9. **Patch manual signing** — run `ci-set-manual-signing.sh` with signing identity and profile name
10. **Update version numbers** — run `update-version.sh` with version from release tag and run number as build number
11. **xcodebuild archive** — build Release archive with hardened runtime (see [Archive Command](#archive-command))
12. **Sign Sparkle artifacts** — run `sign-sparkle.sh` to re-sign all Sparkle framework binaries
13. **Create DMG + notarize** — run `notary.sh` to create DMG, submit to Apple notary, and staple
14. **Generate appcast** — run `generate-appcast.sh` to create appcast.xml with EdDSA signatures
15. **Upload DMG** — attach DMG to the GitHub Release as a release asset
16. **Upload artifacts** — upload appcast.xml and release notes HTML as workflow artifacts for the deploy job

### Certificate import example

```bash
# Create temporary keychain
security create-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
security set-keychain-settings -lut 21600 $KEYCHAIN_PATH
security unlock-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH

# Import certificate
echo "$BUILD_CERTIFICATE_BASE64" | base64 --decode > certificate.p12
security import certificate.p12 -P "$P12_PASSWORD" -A \
  -t cert -f pkcs12 -k $KEYCHAIN_PATH
security set-key-partition-list -S apple-tool:,apple: \
  -k "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
security list-keychain -d user -s $KEYCHAIN_PATH
```

## Job 2: Deploy (Ubuntu)

**Runner:** `ubuntu-latest`
**Condition:** Only runs on `release` events

Steps:

1. **Download artifacts** — appcast.xml and release notes HTML from the build job
2. **Prepare Pages payload** — organize files into a deployment directory:
   - `appcast.xml`
   - `release_notes.html`
   - `CNAME` (e.g. `update.linda.rxlab.app`)
3. **Deploy to GitHub Pages** — using the `actions/deploy-pages` action

## Archive Command

```bash
xcodebuild archive \
  -project ios/ios.xcodeproj \
  -scheme LindaAssistant \
  -configuration Release \
  -destination "platform=macOS" \
  -archivePath output/output.xcarchive \
  -skipPackagePluginValidation \
  OTHER_CODE_SIGN_FLAGS="--options=runtime --timestamp"
```

Key flags:

| Flag | Purpose |
|------|---------|
| `-configuration Release` | Use Release build settings (optimized, signed) |
| `-destination "platform=macOS"` | Build for macOS (not iOS) |
| `-skipPackagePluginValidation` | Allow SPM plugins without sandbox checks |
| `OTHER_CODE_SIGN_FLAGS="--options=runtime --timestamp"` | Enable hardened runtime (required for notarization) |

## DNS Setup

For the update feed URL (e.g. `update.linda.rxlab.app`):

1. Create a CNAME DNS record: `update.linda.rxlab.app` → `rxtech-lab.github.io`
2. Enable GitHub Pages on the repo: Settings → Pages → Source: GitHub Actions
3. The deploy job publishes appcast.xml and release notes to this domain
