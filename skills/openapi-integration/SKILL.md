---
name: openapi-integration
description: Set up and maintain OpenAPI 3.0 integration between a Next.js backend and a Swift iOS client. Use when the user needs to (1) set up OpenAPI spec generation from Zod schemas using next-openapi-gen, (2) configure Swift OpenAPI generator for an iOS package, (3) create or update API routes with JSDoc annotations, (4) create Zod schemas for API contracts, (5) sync the OpenAPI spec between backend and iOS, (6) create Swift service layers wrapping generated API clients, or (7) troubleshoot OpenAPI generation or Swift type issues.
---

# OpenAPI Integration

Type-safe API communication between a Next.js backend and a Swift iOS client via OpenAPI 3.0.

## Architecture

```
Backend (Next.js)                              iOS Client (Swift)
┌──────────────┐   ┌──────────────┐           ┌───────────────────────┐
│ Zod Schemas  │──▶│next-openapi  │──▶ JSON ──▶│swift-openapi-generator│
│              │   │   -gen       │           │ (SPM build plugin)    │
└──────────────┘   └──────────────┘           └───────────┬───────────┘
                                                          ▼
┌──────────────┐                              Types.swift + Client.swift
│ API Routes   │◀── JSDoc @openapi tags               (generated)
│ (app/api/v1) │                                          ▼
└──────────────┘                              Service Layer (manual)
```

## Placeholders

All scripts accept these as arguments — replace with project-specific values:

| Argument | Description | Example |
|----------|-------------|---------|
| `<backend-dir>` | Backend directory | `admin`, `backend`, `web` |
| `<ios-app>` | iOS app root directory | `MyApp`, `RxStorage` |
| `<package-name>` | Swift package name | `MyAppCore`, `RxStorageCore` |

## Workflow

### Initial setup

1. Install `next-openapi-gen` in backend: `./scripts/admin-install-openapi.sh <backend-dir>`
2. Add `"openapi:generate": "next-openapi-gen generate"` to `<backend-dir>/package.json` scripts
3. Create Zod schemas in `<backend-dir>/lib/schemas/` → See [backend-setup.md](references/backend-setup.md)
4. Annotate API routes with JSDoc `@openapi` tags → See [jsdoc-reference.md](references/jsdoc-reference.md)
5. Create the `/api/openapi` serving route → See [backend-setup.md](references/backend-setup.md#serve-the-openapi-spec)
6. Set up Swift package dependencies and generator config → See [ios-setup.md](references/ios-setup.md)
7. Create API client, auth middleware, and service layer → See [ios-setup.md](references/ios-setup.md#api-client-setup)

### After API changes (ongoing workflow)

1. Edit routes in `<backend-dir>/app/api/v1/` or schemas in `<backend-dir>/lib/schemas/`
2. Start server: `bun run dev` in backend directory
3. Regenerate and sync spec: `./scripts/ios-update-openapi.sh <backend-dir> <ios-app> <package-name>`
4. Build iOS package: `./scripts/ios-build-package.sh <ios-app> <package-name>`
5. Update Swift service layer to use new/changed generated types

## Scripts

| Script | Args | Purpose |
|--------|------|---------|
| `admin-install-openapi.sh` | `<backend-dir>` | Install next-openapi-gen |
| `admin-openapi-generate.sh` | `<backend-dir>` | Generate spec from Zod schemas |
| `ios-update-openapi.sh` | `<backend-dir> <ios-app> <package-name>` | Generate + download spec to iOS |
| `ios-download-openapi.sh` | `<ios-app> <package-name>` | Download spec from running server |
| `ios-build-package.sh` | `<ios-app> <package-name>` | Build Swift package (regenerates types) |
| `ios-clean-package.sh` | `<ios-app> <package-name>` | Clean Swift build folder |

Override the server endpoint via env var: `OPENAPI_DOCUMENTATION_ENDPOINT=https://api.example.com/api/openapi`

## References

- **Backend setup** (Zod schemas, route annotations, spec serving): [backend-setup.md](references/backend-setup.md)
- **iOS setup** (Package.swift, API client, middleware, services): [ios-setup.md](references/ios-setup.md)
- **JSDoc tag reference** (all annotation tags for next-openapi-gen): [jsdoc-reference.md](references/jsdoc-reference.md)
- **Troubleshooting** (common issues and fixes): [troubleshooting.md](references/troubleshooting.md)

## Packages

| Component | Package | Version |
|-----------|---------|---------|
| Backend | [next-openapi-gen](https://www.npmjs.com/package/next-openapi-gen) | ^0.9.4 |
| iOS Generator | [swift-openapi-generator](https://github.com/apple/swift-openapi-generator) | ^1.4.0 |
| iOS Runtime | [swift-openapi-runtime](https://github.com/apple/swift-openapi-runtime) | ^1.6.0 |
| iOS Transport | [swift-openapi-urlsession](https://github.com/apple/swift-openapi-urlsession) | ^1.0.0 |
