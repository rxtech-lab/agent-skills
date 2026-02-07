---
name: oauth-authentication
description: Implement OAuth 2.0 authentication for Next.js backend and iOS Swift apps. Use when setting up OAuth/OIDC authentication, configuring Auth.js (NextAuth v5), implementing PKCE flow for iOS, adding Bearer token support, creating auth middleware, setting up token storage/refresh, or writing E2E tests with mock authentication. Covers the full auth stack from provider configuration through session management.
---

## Overview

Implement OAuth 2.0 with OpenID Connect across a Next.js web backend and iOS Swift mobile app. The system supports dual authentication: session cookies for web and Bearer tokens for mobile, with PKCE for secure native app auth.

## Architecture Summary

| Platform | Flow | Client Type | Auth Method |
|----------|------|-------------|-------------|
| Web Admin | Authorization Code | Confidential | Client Secret |
| iOS App | Authorization Code + PKCE | Public | No Secret Required |

Both paths converge at the Next.js API layer, which accepts either Bearer tokens or session cookies via a unified `getSession()` helper.

Read `references/architecture.md` for the full flow diagram and endpoint reference.

## Workflow: Set Up Backend Authentication (Next.js)

### Step 1: Install Dependencies

```bash
npm install next-auth@5.0.0-beta.25
```

### Step 2: Configure Environment

Create `.env` in the backend directory:

```bash
AUTH_SECRET=<openssl rand -base64 32>
AUTH_ISSUER=https://{auth-domain}
AUTH_CLIENT_ID=client_xxx
AUTH_CLIENT_SECRET=secret_xxx
```

### Step 3: Create Auth Configuration

Create `auth.ts` with the OIDC provider, JWT callback (storing tokens + handling refresh), and session callback (exposing tokens).

Read `references/backend-auth.md` for complete Auth.js setup including the refresh token function.

### Step 4: Add Bearer Token Support

Create `lib/auth-helper.ts` with:
- `getBearerToken(request)` - Extract token from Authorization header
- `verifyBearerToken(token)` - Verify against OAuth provider's userinfo endpoint
- `getSession(request?)` - Unified session resolver: tries Bearer token first, falls back to session cookie

Read `references/backend-auth.md` for the full implementation.

### Step 5: Set Up Route Protection

Create middleware (`proxy.ts`) that:
- Allows public paths (`/login`, `/api/auth`, `/api/v1`, etc.)
- Redirects unauthenticated requests to `/login`
- Lets `/api/v1` routes handle their own auth via `getSession()`

### Step 6: Use in API Routes

All `/api/v1` routes follow this pattern:

```typescript
export async function GET(request: NextRequest) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  // Use session.user.id for ownership queries
}
```

## Workflow: Set Up iOS Authentication (Swift)

### Step 1: Configure xcconfig Files

Set up build-time configuration:
- `Debug.xcconfig` - Points to localhost, uses dev client ID
- `Release.xcconfig` - Points to production, uses prod client ID
- `Secrets.xcconfig` (git-ignored) - Contains actual client IDs

Read `references/ios-auth.md` for xcconfig setup and Info.plist integration.

### Step 2: Create AppConfiguration

Singleton that reads OAuth settings from `Bundle.main.infoDictionary` at runtime (populated from xcconfig via Info.plist variable substitution).

### Step 3: Implement OAuthManager

Core authentication class using `ASWebAuthenticationSession` with PKCE:
1. Generate PKCE code verifier (32 random bytes, base64url-encoded)
2. Compute code challenge (SHA256 of verifier, base64url-encoded)
3. Launch browser with authorization URL including challenge
4. Receive callback with authorization code
5. Exchange code for tokens (sending code_verifier, not client_secret)

Read `references/ios-auth.md` for the complete OAuthManager and PKCE implementation.

### Step 4: Implement Token Storage

Use Keychain (`Security` framework) with `kSecAttrAccessibleAfterFirstUnlock` for:
- Access token, refresh token, expiration timestamp
- Actor-based (`TokenStorage`) for thread safety
- 10-minute pre-expiry buffer for proactive refresh

### Step 5: Add Authentication Middleware

Create `AuthenticationMiddleware` (conforming to `ClientMiddleware` from OpenAPIRuntime):
- Inject Bearer token into every request
- Catch 401 responses, attempt token refresh, retry once
- Post `.authSessionExpired` notification if refresh fails

### Step 6: Wire Up SwiftUI

Switch on `authManager.authState` (.unknown / .authenticated / .unauthenticated) to show the appropriate view. Listen for `.authSessionExpired` to trigger sign-out.

## Workflow: Set Up E2E Testing

### Step 1: Enable Mock Mode

Set `IS_E2E=true` environment variable. This causes `getSession()` to return a mock session without OAuth.

### Step 2: Configure Multi-User Testing

Use custom headers to simulate different users:
- `X-Test-User-Id` - Simulate specific user ID
- `X-Test-User-Email` - Simulate specific email

### Step 3: Use In-Memory Database

When `IS_E2E=true`, switch to in-memory SQLite for test isolation.

Read `references/e2e-testing.md` for Playwright config, test examples, iOS UI test setup, and permission testing patterns.

## Security Checklist

- Use PKCE (S256) for all mobile/native clients
- Never embed client secrets in mobile app binaries
- Store tokens in Keychain (iOS) or HttpOnly cookies (web)
- Proactively refresh tokens before expiration
- Clear all tokens on sign-out
- Request `offline_access` scope for refresh tokens

## Troubleshooting

Read `references/troubleshooting.md` for common issues: invalid client errors, 401 failures, token refresh problems, xcconfig setup, and debug logging.
