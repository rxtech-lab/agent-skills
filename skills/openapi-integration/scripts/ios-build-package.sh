#!/bin/bash
# scripts/ios-build-package.sh
# Build the Swift package (triggers OpenAPI type generation).
# Usage: ./scripts/ios-build-package.sh <ios-app> <package-name>
# Example: ./scripts/ios-build-package.sh MyApp MyAppCore

set -e

IOS_APP="${1:?Usage: $0 <ios-app> <package-name>}"
PACKAGE_NAME="${2:?Usage: $0 <ios-app> <package-name>}"

cd "./$IOS_APP/packages/$PACKAGE_NAME" && swift build
echo "Swift package built successfully"
