# Xcode Cloud

## Table of Contents

- [Post-Clone Script (ci_post_clone.sh)](#post-clone-script)
- [Version Bumping Logic](#version-bumping-logic)
- [Environment Variables](#environment-variables)
- [End-to-End Version Flow Example](#end-to-end-version-flow-example)

## Post-Clone Script

**File:** `RxStorage/ci_scripts/ci_post_clone.sh`

Xcode Cloud runs scripts in `ci_scripts/` at specific lifecycle points. `ci_post_clone.sh` executes immediately after cloning. Steps in order:

1. **Trust Swift Package plugins** — required for the OpenAPI code generator
2. **Bump version from tag** — if `CI_TAG` is set, extract version and stamp into Xcode project
3. **Decode secrets** — write `Secrets.xcconfig` from `SECRETS_XCCONFIG_BASE64`
4. **Decode test credentials** — run `scripts/decode-env-secrets.sh`
5. **Install Bun** — download and configure Bun runtime
6. **Start backend server** — install dependencies, run `bun dev:e2e` in background
7. **Wait for backend** — poll `http://localhost:3000` up to 60 seconds
8. **Generate OpenAPI client** — run `scripts/ios-update-openapi.sh`

## Version Bumping Logic

The core version stamping in `ci_post_clone.sh`:

```bash
if [ -n "$CI_TAG" ]; then
    VERSION="${CI_TAG#v}"   # v1.2.3 → 1.2.3
    echo "Setting MARKETING_VERSION=$VERSION, CURRENT_PROJECT_VERSION=$CI_BUILD_NUMBER"
    cd "$REPO_ROOT/RxStorage"

    # Update MARKETING_VERSION directly in project.pbxproj
    # (agvtool new-marketing-version only updates Info.plist, not the
    # build setting used when GENERATE_INFOPLIST_FILE=YES)
    sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $VERSION;/g" \
        RxStorage.xcodeproj/project.pbxproj

    # Update CURRENT_PROJECT_VERSION (build number) using agvtool
    agvtool new-version -all "$CI_BUILD_NUMBER"
    cd "$REPO_ROOT"
fi
```

Why `sed` instead of `agvtool new-marketing-version`:
- With `GENERATE_INFOPLIST_FILE=YES`, Xcode reads `MARKETING_VERSION` from the build setting in `project.pbxproj`, not from `Info.plist`
- `agvtool new-marketing-version` only updates `Info.plist`, so it has no effect
- `sed` directly modifies the build setting in the project file

Why `agvtool` for build number:
- `agvtool new-version -all` correctly updates `CURRENT_PROJECT_VERSION` across all targets
- `CI_BUILD_NUMBER` is auto-incremented by Xcode Cloud

## Environment Variables

Xcode Cloud environment variables (configured in Xcode Cloud settings):

| Variable | Source | Purpose |
|----------|--------|---------|
| `CI_TAG` | Auto-set by Xcode Cloud | Git tag that triggered the build (e.g., `v1.2.3`) |
| `CI_BUILD_NUMBER` | Auto-set by Xcode Cloud | Auto-incrementing build number |
| `SECRETS_XCCONFIG_BASE64` | Manual config | Base64-encoded `Secrets.xcconfig` with OAuth client IDs |
| `RXSTORAGE_TESTING_SECRETS` | Manual config | Base64-encoded `.env` with test credentials |

## End-to-End Version Flow Example

Releasing version `v1.2.0`:

```
1. Developer commits:
   feat: add stock history support
   fix: photo picker error

2. Maintainer triggers "Create Release" workflow on main

3. Semantic Release:
   - Finds feat: commit → minor bump
   - Last tag was v1.1.1 → new version is v1.2.0
   - Creates git tag: v1.2.0
   - Creates GitHub Release with auto-generated notes

4. Xcode Cloud detects tag v1.2.0:
   - CI_TAG = "v1.2.0"
   - CI_BUILD_NUMBER = 47 (auto-incremented)

5. ci_post_clone.sh runs:
   - VERSION = "1.2.0" (stripped "v" prefix)
   - sed updates MARKETING_VERSION = 1.2.0 in project.pbxproj
   - agvtool sets CURRENT_PROJECT_VERSION = 47

6. Xcode Cloud builds, signs, uploads to TestFlight
   - App Store shows: Version 1.2.0 (47)
```
