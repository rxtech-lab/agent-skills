#!/bin/bash
# scripts/admin-install-openapi.sh
# Install next-openapi-gen in the backend (Next.js) directory.
# Usage: ./scripts/admin-install-openapi.sh <backend-dir>
# Example: ./scripts/admin-install-openapi.sh admin

set -e

BACKEND_DIR="${1:?Usage: $0 <backend-dir>}"

cd "./$BACKEND_DIR" && bun add next-openapi-gen
echo "next-openapi-gen installed in $BACKEND_DIR"
