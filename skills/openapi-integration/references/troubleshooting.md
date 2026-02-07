# Troubleshooting

## Backend Issues

### OpenAPI spec not generating
```bash
./scripts/admin-openapi-generate.sh <backend-dir>
```
Check for Zod schema errors in `<backend-dir>/lib/schemas/`.

### Schema not appearing in spec
- Ensure schema is exported from `<backend-dir>/lib/schemas/index.ts`
- Check that the API route has the `@openapi` JSDoc tag (**required**)
- Verify the schema name in `@body`, `@response`, or `@params` matches the export name exactly

### Server URL not correct
- The `/api/openapi` endpoint dynamically sets the server URL from the request
- For production, ensure the `x-forwarded-proto` header is set correctly by the reverse proxy

## iOS Issues

### Types not generating
```bash
./scripts/ios-clean-package.sh <ios-app> <package-name>
./scripts/ios-build-package.sh <ios-app> <package-name>
```

### "openapi.json not found" error
- Ensure `openapi.json` is in the same directory as `openapi-generator-config.yaml`
- Run `./scripts/ios-download-openapi.sh <ios-app> <package-name>`

### Invalid JSON error
```bash
python3 -m json.tool <ios-app>/packages/<package-name>/Sources/<package-name>/openapi.json
```

### Date decoding errors
The backend sends ISO8601 dates with fractional seconds (e.g., `2024-01-15T10:30:00.000Z`). Configure the client:
```swift
let clientConfiguration = Configuration(
    dateTranscoder: .iso8601WithFractionalSeconds
)
```
