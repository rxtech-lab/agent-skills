# Scripts Reference

## Table of Contents

- [ci-set-manual-signing.sh](#ci-set-manual-signingsh)
- [update-version.sh](#update-versionsh)
- [sign-sparkle.sh](#sign-sparklesh)
- [notary.sh](#notarysh)
- [generate-appcast.sh](#generate-appcastsh)
- [convert-markdown.py](#convert-markdownpy)
- [update-xml.py](#update-xmlpy)

All scripts are in `scripts/` and run from the project root.

## ci-set-manual-signing.sh

**Usage:** `scripts/ci-set-manual-signing.sh <identity> <profile_name>`

Patches `project.pbxproj` to switch from Automatic to Manual code signing for the Release build configuration. Uses `sed` to replace `CODE_SIGN_STYLE`, `CODE_SIGN_IDENTITY`, and `PROVISIONING_PROFILE_SPECIFIER` in-place using the target's UUID.

| Argument | Description | Example |
|----------|-------------|---------|
| `identity` | Full signing identity | `"Developer ID Application: Your Name (TEAMID)"` |
| `profile_name` | Provisioning profile name | `"LindaAssistant Developer ID"` |

## update-version.sh

**Usage:** `scripts/update-version.sh <version> [build_number]`

Updates `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.pbxproj` globally. Typically called with the version extracted from the release tag and the GitHub Actions run number as the build number.

| Argument | Description | Example |
|----------|-------------|---------|
| `version` | Semver version from release tag | `1.2.3` |
| `build_number` | Optional build number (defaults to existing) | `42` |

## sign-sparkle.sh

**Usage:** `scripts/sign-sparkle.sh`

Re-signs all Sparkle framework binaries inside the `.xcarchive` with hardened runtime and timestamp. This is required for Apple notarization to pass.

Signs the following components in order:

1. XPC services: Downloader, Installer
2. Updater.app
3. Autoupdate binary
4. Sparkle framework itself
5. Main app bundle

**Environment variables:**

| Variable | Description |
|----------|-------------|
| `SIGNING_CERTIFICATE_NAME` | Full signing identity (e.g. `"Developer ID Application: ..."`) |

## notary.sh

**Usage:** `scripts/notary.sh`

Creates a DMG from the archived app using `create-dmg`, then submits it to Apple's notarization service via `xcrun notarytool`. After notarization succeeds, staples the ticket to the DMG.

**Environment variables:**

| Variable | Required | Description |
|----------|----------|-------------|
| `APPLE_ID` | Yes | Apple ID email for notarization |
| `APPLE_ID_PWD` | Yes | App-specific password for notarization |
| `APPLE_TEAM_ID` | Yes | Apple Developer Team ID |
| `SKIP_NOTARIZE` | No | Set to `true` to skip notarization (for non-release CI builds) |

## generate-appcast.sh

**Usage:** `scripts/generate-appcast.sh`

Generates the Sparkle appcast.xml feed:

1. Writes the EdDSA private key to a temporary file
2. Converts release notes from Markdown to HTML (via `convert-markdown.py`)
3. Runs `bin/generate_appcast` to create `appcast.xml` with download URLs pointing to GitHub Release assets
4. Patches the XML with release notes links and build numbers (via `update-xml.py`)

**Environment variables:**

| Variable | Description |
|----------|-------------|
| `SPARKLE_KEY` | Sparkle EdDSA private key |
| `VERSION` | Release version (e.g. `1.2.3`) |
| `BUILD_NUMBER` | Build number (GitHub Actions run number) |
| `RELEASE_TAG` | Git release tag (e.g. `v1.2.3`) |
| `RELEASE_NOTE` | Release notes in Markdown format |
| `GITHUB_REPOSITORY` | Repository in `owner/repo` format |

## convert-markdown.py

**Usage:** `scripts/convert-markdown.py <input.md> <output.html>`

Converts Markdown release notes to a styled HTML page with:

- System font (`-apple-system`)
- Dark mode support via `prefers-color-scheme`
- Code block styling

Used by Sparkle to display release notes in the update dialog.

## update-xml.py

**Usage:** `scripts/update-xml.py <appcast.xml> <notes_path> [build_number]`

Patches the generated `appcast.xml` to add:

- `<sparkle:releaseNotesLink>` — points to the HTML release notes file deployed alongside the appcast
- `<sparkle:version>` — the build number for each item

| Argument | Description |
|----------|-------------|
| `appcast.xml` | Path to the generated appcast file |
| `notes_path` | Path or URL to the HTML release notes |
| `build_number` | Optional build number to inject |
