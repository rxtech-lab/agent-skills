# E2E Testing Reference

## Table of Contents

- [Mock Session Setup](#mock-session-setup)
- [Playwright Configuration](#playwright-configuration)
- [Multi-User Headers](#multi-user-headers)
- [In-Memory Database](#in-memory-database)
- [Test Examples](#test-examples)
- [iOS UI Testing](#ios-ui-testing)

## Mock Session Setup

When `IS_E2E=true`, `getSession()` returns a mock session bypassing OAuth entirely.

File: `lib/auth-helper.ts` (E2E additions)

```typescript
export async function getSession(request?: NextRequest) {
  if (process.env.IS_E2E === "true") {
    const testUserId = request?.headers.get("X-Test-User-Id") || "test-user-id";
    const testUserEmail = request?.headers.get("X-Test-User-Email") || "test@example.com";

    return {
      user: {
        id: testUserId,
        email: testUserEmail,
        name: "Test User",
      },
      accessToken: "mock-access-token",
    };
  }

  // Normal OAuth flow...
}
```

Middleware bypass in `proxy.ts`:

```typescript
export default auth((req) => {
  if (process.env.IS_E2E === "true") {
    return NextResponse.next();
  }
  // Normal auth checks...
});
```

## Playwright Configuration

```typescript
// playwright.config.ts
import { defineConfig } from "@playwright/test";

export default defineConfig({
  use: {
    baseURL: "http://localhost:3000",
  },
  webServer: {
    command: "bun run dev",
    url: "http://localhost:3000",
    reuseExistingServer: !process.env.CI,
    env: {
      IS_E2E: "true",
    },
  },
});
```

Package.json scripts:

```json
{
  "scripts": {
    "test:e2e": "IS_E2E=true playwright test",
    "test:e2e:ui": "IS_E2E=true playwright test --ui",
    "test:e2e:debug": "IS_E2E=true playwright test --debug"
  }
}
```

## Multi-User Headers

| Header | Purpose | Default |
|--------|---------|---------|
| `X-Test-User-Id` | Simulate user ID | `"test-user-id"` |
| `X-Test-User-Email` | Simulate user email | `"test@example.com"` |

## In-Memory Database

```typescript
// lib/db/client.ts
export function createClient() {
  if (process.env.IS_E2E === "true") {
    return createClient({ url: ":memory:" });
  }

  return createClient({
    url: process.env.TURSO_DATABASE_URL!,
    authToken: process.env.TURSO_AUTH_TOKEN,
  });
}
```

## Test Examples

### Basic CRUD Test

```typescript
import { test, expect } from "@playwright/test";

const USER_A = "user-a-id";

test.describe("Items API", () => {
  test("user can create and retrieve items", async ({ request }) => {
    const createResponse = await request.post("/api/v1/items", {
      headers: { "X-Test-User-Id": USER_A },
      data: {
        title: "Test Item",
        description: "Created in E2E test",
      },
    });
    expect(createResponse.ok()).toBeTruthy();

    const item = await createResponse.json();
    expect(item.title).toBe("Test Item");

    const listResponse = await request.get("/api/v1/items", {
      headers: { "X-Test-User-Id": USER_A },
    });
    expect(listResponse.ok()).toBeTruthy();

    const items = await listResponse.json();
    expect(items).toContainEqual(expect.objectContaining({ id: item.id }));
  });
});
```

### Multi-User Isolation Test

```typescript
const USER_A = "user-a-id";
const USER_B = "user-b-id";

test.describe("User Isolation", () => {
  test("users cannot see each other's items", async ({ request }) => {
    const createResponse = await request.post("/api/v1/items", {
      headers: { "X-Test-User-Id": USER_A },
      data: { title: "User A's Private Item" },
    });
    const item = await createResponse.json();

    const listResponse = await request.get("/api/v1/items", {
      headers: { "X-Test-User-Id": USER_B },
    });
    const items = await listResponse.json();

    expect(items).not.toContainEqual(
      expect.objectContaining({ id: item.id })
    );
  });
});
```

### Permission Testing with Email Whitelist

```typescript
const OWNER = "owner-id";
const OWNER_EMAIL = "owner@example.com";
const WHITELISTED_USER = "whitelisted-id";
const WHITELISTED_EMAIL = "whitelisted@example.com";
const OTHER_USER = "other-id";
const OTHER_EMAIL = "other@example.com";

test.describe("Item Permissions", () => {
  test("whitelisted user can access private item", async ({ request }) => {
    const createResponse = await request.post("/api/v1/items", {
      headers: {
        "X-Test-User-Id": OWNER,
        "X-Test-User-Email": OWNER_EMAIL,
      },
      data: {
        title: "Private Item",
        isPublic: false,
        whitelistedEmails: [WHITELISTED_EMAIL],
      },
    });
    const item = await createResponse.json();

    // Whitelisted user CAN access
    const whitelistedAccess = await request.get(`/api/v1/items/${item.id}`, {
      headers: {
        "X-Test-User-Id": WHITELISTED_USER,
        "X-Test-User-Email": WHITELISTED_EMAIL,
      },
    });
    expect(whitelistedAccess.ok()).toBeTruthy();

    // Other user CANNOT access
    const otherAccess = await request.get(`/api/v1/items/${item.id}`, {
      headers: {
        "X-Test-User-Id": OTHER_USER,
        "X-Test-User-Email": OTHER_EMAIL,
      },
    });
    expect(otherAccess.status()).toBe(403);
  });
});
```

## iOS UI Testing

Bypass OAuth by setting environment variables on app launch:

```swift
// TestHelpers.swift
import XCTest

extension XCUIApplication {
    func launchForTesting() {
        launchEnvironment["IS_E2E"] = "true"
        launchEnvironment["MOCK_AUTH_TOKEN"] = "test-token"
        launch()
    }
}
```

```swift
// ItemsUITests.swift
import XCTest

final class ItemsUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchForTesting()
    }

    func testItemList() throws {
        let itemList = app.collectionViews["itemList"]
        XCTAssertTrue(itemList.exists)
    }
}
```
