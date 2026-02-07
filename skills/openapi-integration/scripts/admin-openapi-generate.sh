#!/bin/bash
# scripts/admin-openapi-generate.sh
# Generate OpenAPI spec from Zod schemas in the backend directory.
# Usage: ./scripts/admin-openapi-generate.sh <backend-dir>
# Example: ./scripts/admin-openapi-generate.sh admin

set -e

BACKEND_DIR="${1:?Usage: $0 <backend-dir>}"

cd "./$BACKEND_DIR" && bun run openapi:generate
echo "OpenAPI spec generated at $BACKEND_DIR/public/openapi.json"
