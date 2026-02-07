#!/bin/bash
# scripts/ios-update-openapi.sh
# Generate backend OpenAPI spec AND download it to the iOS Swift package.
# Usage: ./scripts/ios-update-openapi.sh <backend-dir> <ios-app> <package-name>
# Example: ./scripts/ios-update-openapi.sh admin MyApp MyAppCore
#
# Override endpoint: Set OPENAPI_DOCUMENTATION_ENDPOINT env var.
# Example: OPENAPI_DOCUMENTATION_ENDPOINT=https://api.example.com/api/openapi ./scripts/ios-update-openapi.sh admin MyApp MyAppCore

set -e

BACKEND_DIR="${1:?Usage: $0 <backend-dir> <ios-app> <package-name>}"
IOS_APP="${2:?Usage: $0 <backend-dir> <ios-app> <package-name>}"
PACKAGE_NAME="${3:?Usage: $0 <backend-dir> <ios-app> <package-name>}"

# Step 1: Generate OpenAPI spec from Zod schemas
cd "./$BACKEND_DIR"
bun run openapi:generate
cd ../

# Step 2: Download spec to iOS package
TARGET_FILE="./$IOS_APP/packages/$PACKAGE_NAME/Sources/$PACKAGE_NAME/openapi.json"
ENDPOINT="${OPENAPI_DOCUMENTATION_ENDPOINT:-http://localhost:3000/api/openapi}"

echo "Downloading OpenAPI spec from: $ENDPOINT"
curl -sS -o "$TARGET_FILE" "$ENDPOINT"

# Step 3: Validate JSON
echo "Validating JSON..."
if ! python3 -m json.tool "$TARGET_FILE" > /dev/null 2>&1; then
    echo "Error: Downloaded file is not valid JSON"
    echo "Contents of $TARGET_FILE:"
    head -20 "$TARGET_FILE"
    exit 1
fi

echo "OpenAPI spec updated at: $TARGET_FILE"
