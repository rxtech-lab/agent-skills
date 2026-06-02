#!/usr/bin/env bash
# set-version.sh — stamp app.json .expo.version from the release tag.
#
# Usage:
#   set-version.sh <version>        # explicit, e.g. 1.2.3
#   set-version.sh                   # derive from $GITHUB_REF_NAME (v1.2.3 -> 1.2.3)
#
# Run from the Expo app directory (where app.json lives).
# versionName only — the Android versionCode is owned by EAS (appVersionSource=remote).
set -euo pipefail

VERSION="${1:-${GITHUB_REF_NAME#v}}"

if [[ -z "$VERSION" ]]; then
  echo "error: no version given and GITHUB_REF_NAME is empty" >&2
  exit 1
fi

if [[ ! -f app.json ]]; then
  echo "error: app.json not found in $(pwd)" >&2
  exit 1
fi

cat <<< "$(jq --arg v "$VERSION" '.expo.version = $v' app.json)" > app.json
echo "app.json .expo.version set to $VERSION"
