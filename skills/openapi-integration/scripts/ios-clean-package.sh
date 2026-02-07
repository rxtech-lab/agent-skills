#!/bin/bash
# scripts/ios-clean-package.sh
# Clean the Swift package build folder to force regeneration.
# Usage: ./scripts/ios-clean-package.sh <ios-app> <package-name>
# Example: ./scripts/ios-clean-package.sh MyApp MyAppCore

IOS_APP="${1:?Usage: $0 <ios-app> <package-name>}"
PACKAGE_NAME="${2:?Usage: $0 <ios-app> <package-name>}"

rm -rf "./$IOS_APP/packages/$PACKAGE_NAME/.build"
echo "Swift package cleaned"
