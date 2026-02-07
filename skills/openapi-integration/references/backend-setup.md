# Backend Setup (Next.js + Zod + next-openapi-gen)

## Table of Contents
- [Install next-openapi-gen](#install)
- [Configure package.json](#configure-packagejson)
- [Define Zod Schemas](#define-zod-schemas)
- [Annotate API Routes](#annotate-api-routes)
- [Serve the OpenAPI Spec](#serve-the-openapi-spec)
- [Generate the Spec](#generate-the-spec)

## Install

Run from repository root:
```bash
./scripts/admin-install-openapi.sh <backend-dir>
```

## Configure package.json

Add to `<backend-dir>/package.json`:
```json
{
  "scripts": {
    "dev": "next dev",
    "build": "bun db:push && bun openapi:generate && next build",
    "openapi:generate": "next-openapi-gen generate"
  },
  "dependencies": {
    "next-openapi-gen": "^0.9.4",
    "zod": "^3.25.76"
  }
}
```

## Define Zod Schemas

All API schemas live in `<backend-dir>/lib/schemas/`. They are automatically converted to OpenAPI schemas.

### Common schemas (`lib/schemas/common.ts`)

```typescript
import { z } from "zod";

export const PaginationQueryParams = z.object({
  cursor: z.string().optional().describe("Base64 encoded cursor for pagination"),
  direction: z.enum(["next", "prev"]).optional().describe("Pagination direction"),
  limit: z.coerce.number().int().min(1).max(100).optional().describe("Items per page (default: 20, max: 100)"),
});

export const PaginationInfo = z.object({
  nextCursor: z.string().nullable().describe("Cursor for next page"),
  prevCursor: z.string().nullable().describe("Cursor for previous page"),
  hasNextPage: z.boolean().describe("Whether more items exist after current page"),
  hasPrevPage: z.boolean().describe("Whether items exist before current page"),
});

export const ErrorResponse = z.object({
  error: z.string().describe("Error message"),
});

export const SuccessResponse = z.object({
  success: z.literal(true).describe("Operation succeeded"),
});

export const IdPathParams = z.object({
  id: z.string().describe("Resource ID"),
});
```

### Resource schemas pattern (e.g., `lib/schemas/items.ts`)

```typescript
import { z } from "zod";
import { PaginationInfo, PaginationQueryParams } from "./common";

// Insert schema — fields required for creation
export const ItemInsertSchema = z.object({
  title: z.string().describe("Item title"),
  description: z.string().nullable().optional().describe("Item description"),
  categoryId: z.number().int().nullable().optional().describe("Category ID reference"),
  visibility: z.enum(["publicAccess", "privateAccess"]).describe("Visibility setting"),
  images: z.array(z.string()).optional().describe("Image file references"),
});

// Update schema — all fields optional
export const ItemUpdateSchema = z.object({
  title: z.string().optional().describe("Item title"),
  description: z.string().nullable().optional().describe("Item description"),
  categoryId: z.number().int().nullable().optional().describe("Category ID reference"),
  visibility: z.enum(["publicAccess", "privateAccess"]).optional().describe("Visibility setting"),
});

// Response schema — all fields present
export const ItemResponseSchema = z.object({
  id: z.number().int().describe("Unique item identifier"),
  userId: z.string().describe("Owner user ID"),
  title: z.string().describe("Item title"),
  description: z.string().nullable().describe("Item description"),
  categoryId: z.number().int().nullable().describe("Category ID reference"),
  locationId: z.number().int().nullable().describe("Location ID reference"),
  visibility: z.enum(["publicAccess", "privateAccess"]).describe("Visibility setting"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
  updatedAt: z.coerce.date().describe("Last update timestamp"),
  previewUrl: z.string().url().describe("Public preview URL"),
});

// Query params for list endpoint
export const ItemsQueryParams = PaginationQueryParams.extend({
  search: z.string().optional().describe("Search query"),
  categoryId: z.coerce.number().int().optional().describe("Filter by category ID"),
  visibility: z.enum(["publicAccess", "privateAccess"]).optional().describe("Filter by visibility"),
});

// Paginated response - return items directly without wrapping in `data`
export const PaginatedItemsResponse = z.object({
  items: z.array(ItemResponseSchema).describe("Array of items"),
  pagination: PaginationInfo,
});
```

### Export all schemas (`lib/schemas/index.ts`)

```typescript
export * from "./common";
export * from "./items";
export * from "./categories";
export * from "./locations";
// ... add other resource schemas
```

## Annotate API Routes

Use JSDoc with special tags on route handlers. The `@openapi` tag is **required** for inclusion.

### List + Create endpoint (`app/api/v1/items/route.ts`)

```typescript
import { NextRequest, NextResponse } from "next/server";

/**
 * List items
 * @operationId getItems
 * @description Retrieve a paginated list of items with optional filters
 * @params ItemsQueryParams
 * @response PaginatedItemsResponse
 * @auth bearer
 * @tag Items
 * @responseSet auth
 * @openapi
 */
export async function GET(request: NextRequest) {
  // ... implementation
}

/**
 * Create item
 * @operationId createItem
 * @description Create a new item
 * @body ItemInsertSchema
 * @response 201:ItemResponseSchema
 * @auth bearer
 * @tag Items
 * @responseSet auth
 * @openapi
 */
export async function POST(request: NextRequest) {
  // ... implementation
}
```

### Single-resource endpoint (`app/api/v1/items/[id]/route.ts`)

```typescript
/**
 * Get item by ID
 * @operationId getItem
 * @description Retrieve a specific item by its ID
 * @pathParams IdPathParams
 * @response ItemResponseSchema
 * @auth bearer
 * @tag Items
 * @responseSet auth
 * @openapi
 */
export async function GET(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  // ... implementation
}

/**
 * Update item
 * @operationId updateItem
 * @description Update an existing item
 * @pathParams IdPathParams
 * @body ItemUpdateSchema
 * @response ItemResponseSchema
 * @auth bearer
 * @tag Items
 * @responseSet auth
 * @openapi
 */
export async function PUT(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  // ... implementation
}

/**
 * Delete item
 * @operationId deleteItem
 * @description Delete an item by ID
 * @pathParams IdPathParams
 * @response 204:
 * @auth bearer
 * @tag Items
 * @responseSet auth
 * @openapi
 */
export async function DELETE(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  // ... implementation
}
```

## Serve the OpenAPI Spec

Create `<backend-dir>/app/api/openapi/route.ts`:

```typescript
import { NextRequest, NextResponse } from "next/server";
import fs from "fs";
import path from "path";

/**
 * Get OpenAPI specification
 * @description Returns the OpenAPI 3.0 specification
 * @response object
 * @tag Documentation
 * @openapi
 */
export async function GET(request: NextRequest) {
  const openapiPath = path.join(process.cwd(), "public", "openapi.json");

  try {
    const spec = JSON.parse(fs.readFileSync(openapiPath, "utf-8"));

    const host = request.headers.get("host") || "localhost:3000";
    const protocol = request.headers.get("x-forwarded-proto") || "http";
    spec.servers = [{ url: `${protocol}://${host}`, description: "Current server" }];

    return new NextResponse(JSON.stringify(spec, null, 2), {
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch {
    return NextResponse.json(
      { error: "OpenAPI specification not found. Run 'bun openapi:generate' first." },
      { status: 404 }
    );
  }
}
```

## Generate the Spec

```bash
./scripts/admin-openapi-generate.sh <backend-dir>
```

Output: `<backend-dir>/public/openapi.json`
