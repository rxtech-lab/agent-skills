---
name: sparkle-github-release
description: Set up and manage macOS app releases with Sparkle auto-update via GitHub Actions. Use when the user needs to (1) configure the macOS release pipeline (build, sign, notarize, distribute), (2) integrate Sparkle framework for auto-updates in a Swift macOS app, (3) create or modify the GitHub Actions release workflow (macos-release.yml), (4) generate or debug Sparkle appcast.xml feeds, (5) configure or rotate signing/notarization secrets, (6) set up GitHub Pages deployment for appcast hosting, (7) write or update CI scripts for code signing, notarization, or appcast generation, or (8) troubleshoot DMG creation, notarization failures, or Sparkle update issues.
---

# Sparkle GitHub Release

macOS app release pipeline: **GitHub Actions** for building, code signing, notarization, and Sparkle auto-update distribution.

## Architecture

```
GitHub Release (vX.Y.Z tag)
         │
         ▼
  GitHub Actions (self-hosted macOS)
         │
         ├──► xcodebuild archive (manual signing, hardened runtime)
         │
         ├──► Sign Sparkle framework artifacts
         │
         ├──► Create DMG + notarize with Apple
         │
         ├──► Generate appcast.xml (EdDSA signatures)
         │
         ├──► Upload DMG to GitHub Release
         │
         ▼
  GitHub Actions (ubuntu-latest)
         │
         └──► Deploy appcast.xml + release notes to GitHub Pages
                    │
                    ▼
           update.{domain}/appcast.xml ◄── Sparkle checks for updates
```

## Release Workflow

### Creating a release

1. Ensure all GitHub secrets are configured → See [secrets.md](references/secrets.md)
2. Create a GitHub Release with a semver tag (e.g. `v1.0.0`)
3. Write release notes in the release body (Markdown)
4. The workflow automatically builds, signs, notarizes, and deploys
5. The DMG appears as a release asset; appcast.xml is deployed to Pages
6. Users with the app installed receive the update via Sparkle

### Pipeline stages

| Stage | Tool | Output |
|-------|------|--------|
| Archive | `xcodebuild archive` | `.xcarchive` with hardened runtime |
| Sign Sparkle | `sign-sparkle.sh` | Re-signed Sparkle XPC services + framework |
| DMG + Notarize | `notary.sh` + `create-dmg` | Notarized, stapled `.dmg` |
| Appcast | `generate-appcast.sh` | `appcast.xml` with EdDSA signatures |
| Deploy | GitHub Pages action | `update.{domain}/appcast.xml` |

### Version identifiers

| Field | Build Setting | Source | Example |
|-------|---------------|--------|---------|
| Version | `MARKETING_VERSION` | Release tag (e.g. `1.0.0`) | `1.2.3` |
| Build | `CURRENT_PROJECT_VERSION` | GitHub Actions run number | `42` |

## File Reference

| File | Purpose |
|------|---------|
| `.github/workflows/macos-release.yml` | Full release pipeline (build + deploy) |
| `scripts/ci-set-manual-signing.sh` | Switch to manual code signing for CI |
| `scripts/update-version.sh` | Stamp version numbers from release tag |
| `scripts/sign-sparkle.sh` | Re-sign Sparkle framework for notarization |
| `scripts/notary.sh` | Create DMG and notarize with Apple |
| `scripts/generate-appcast.sh` | Generate Sparkle appcast.xml feed |
| `scripts/convert-markdown.py` | Convert release notes to styled HTML |
| `scripts/update-xml.py` | Patch appcast.xml with release notes links |
| `bin/generate_appcast` | Sparkle binary for appcast generation |

## Scripts

| Script | Args | Purpose |
|--------|------|---------|
| `ci-set-manual-signing.sh` | `<identity> <profile_name>` | Patch project.pbxproj for manual signing |
| `update-version.sh` | `<version> [build_number]` | Update MARKETING_VERSION and build number |
| `sign-sparkle.sh` | (none, uses env) | Re-sign Sparkle binaries with hardened runtime |
| `notary.sh` | (none, uses env) | Create DMG, notarize, and staple |
| `generate-appcast.sh` | (none, uses env) | Generate appcast.xml with EdDSA signatures |
| `convert-markdown.py` | `<input.md> <output.html>` | Markdown to styled HTML for release notes |
| `update-xml.py` | `<appcast.xml> <notes_path> [build_number]` | Add release notes link and build number to appcast |

Read `references/scripts.md` for detailed script documentation including environment variables and implementation details.

## References

- **GitHub Actions workflow** (trigger, jobs, archive command, deploy): [github-actions.md](references/github-actions.md)
- **Sparkle integration** (Swift setup, Info.plist, SPM dependency): [sparkle-integration.md](references/sparkle-integration.md)
- **Scripts** (all CI scripts with env vars and behavior): [scripts.md](references/scripts.md)
- **Secrets management** (required secrets, how to generate each one): [secrets.md](references/secrets.md)
