# JSDoc Tag Reference for next-openapi-gen

Every API route handler that should appear in the OpenAPI spec **must** include the `@openapi` tag.

## Tags

| Tag | Required | Description | Example |
|-----|----------|-------------|---------|
| `@openapi` | **Yes** | Marker tag — required for inclusion in spec | `@openapi` |
| `@operationId` | Yes | Unique operation identifier (used as Swift method name) | `@operationId getItems` |
| `@description` | Yes | Human-readable description | `@description Retrieve paginated items` |
| `@tag` | Yes | API grouping tag | `@tag Items` |
| `@params` | No | Query parameter schema name (from Zod exports) | `@params ItemsQueryParams` |
| `@pathParams` | No | Path parameter schema name | `@pathParams IdPathParams` |
| `@body` | No | Request body schema name | `@body ItemInsertSchema` |
| `@response` | No | Response schema (optional `status:` prefix) | `@response 201:ItemResponseSchema` |
| `@auth` | No | Authentication type | `@auth bearer` |
| `@responseSet` | No | Predefined response set (e.g., `auth` adds 401) | `@responseSet auth` |

## Response status codes

- Default (no prefix): `200`
- With prefix: `@response 201:ItemResponseSchema`
- No body: `@response 204:`

## Full annotated example

```typescript
/**
 * Create item
 * @operationId createItem
 * @description Create a new storage item
 * @body ItemInsertSchema
 * @response 201:ItemResponseSchema
 * @auth bearer
 * @tag Items
 * @responseSet auth
 * @openapi
 */
export async function POST(request: NextRequest) {
  // ...
}
```

## Common mistakes

- Missing `@openapi` tag → route is silently excluded from spec
- Schema name in `@body`/`@response`/`@params` does not match the exported Zod variable name
- Forgetting to export new schemas from `lib/schemas/index.ts`
