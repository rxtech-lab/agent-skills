#!/usr/bin/env bash
# decode-service-account.sh — decode the Google Play service-account JSON at runtime.
#
# Usage:
#   GOOGLE_SERVICE_ACCOUNT_B64=... decode-service-account.sh [output_path]
#
# Default output: ./google-service-account.json (must be gitignored — contains a
# plaintext private_key). eas.json's submit profile points serviceAccountKeyPath here.
set -euo pipefail

OUT="${1:-./google-service-account.json}"

if [[ -z "${GOOGLE_SERVICE_ACCOUNT_B64:-}" ]]; then
  echo "error: GOOGLE_SERVICE_ACCOUNT_B64 is not set" >&2
  exit 1
fi

echo "$GOOGLE_SERVICE_ACCOUNT_B64" | base64 -d > "$OUT"

# Sanity check: valid JSON with a service_account type.
if ! jq -e '.type == "service_account"' "$OUT" >/dev/null 2>&1; then
  echo "error: decoded file at $OUT is not a valid service-account JSON" >&2
  exit 1
fi

echo "service account written to $OUT"
