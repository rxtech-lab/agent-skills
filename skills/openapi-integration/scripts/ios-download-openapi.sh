#!/bin/bash
# scripts/ios-download-openapi.sh
# Download OpenAPI spec from a running server to the iOS package.
# Does NOT regenerate the backend spec — use ios-update-openapi.sh for that.
# Usage: ./scripts/ios-download-openapi.sh <ios-app> <package-name>
# Example: ./scripts/ios-download-openapi.sh MyApp MyAppCore
#
# Override endpoint: Set OPENAPI_DOCUMENTATION_ENDPOINT env var.

set -e

IOS_APP="${1:?Usage: $0 <ios-app> <package-name>}"
PACKAGE_NAME="${2:?Usage: $0 <ios-app> <package-name>}"

TARGET_FILE="./$IOS_APP/packages/$PACKAGE_NAME/Sources/$PACKAGE_NAME/openapi.json"
ENDPOINT="${OPENAPI_DOCUMENTATION_ENDPOINT:-http://localhost:3000/api/openapi}"

echo "Downloading OpenAPI spec from: $ENDPOINT"
curl -sS -o "$TARGET_FILE" "$ENDPOINT"

if python3 -m json.tool "$TARGET_FILE" > /dev/null 2>&1; then
    echo "OpenAPI spec updated at: $TARGET_FILE"
else
    echo "Error: Downloaded file is not valid JSON"
    exit 1
fi
