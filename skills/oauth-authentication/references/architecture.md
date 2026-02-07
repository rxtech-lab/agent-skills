# OAuth Architecture Reference

## Flow Diagram

```
  iOS App (PKCE)                 Web Admin                OAuth Provider
  ┌──────────────┐              ┌──────────────┐         ┌──────────────┐
  │              │              │              │         │              │
  │ 1. Generate  │              │ 1. Redirect  │         │              │
  │    PKCE      │──────────────│    to OAuth  │────────>│ /authorize   │
  │    params    │              │              │         │              │
  │              │              │              │         │              │
  │ 2. Launch    │              │              │         │ 2. User      │
  │    browser   │──────────────────────────────────────>│    login     │
  │              │              │              │         │              │
  │ 3. Receive   │<─────────────────────────────────────│ 3. Redirect  │
  │    callback  │              │              │         │    with code │
  │              │              │              │         │              │
  │ 4. Exchange  │              │ 4. Exchange  │         │              │
  │    code      │──────────────│    code      │────────>│ /token       │
  │    (+ PKCE)  │              │    (+ secret)│         │              │
  │              │              │              │         │              │
  │ 5. Store     │              │ 5. Session   │<────────│ 5. Return    │
  │    tokens    │              │    cookie    │         │    tokens    │
  └──────────────┘              └──────────────┘         └──────────────┘
         │                             │
         │ Bearer Token                │ Session Cookie
         v                             v
  ┌──────────────────────────────────────────────────────────────────┐
  │                      Next.js API Routes                          │
  │                        /api/v1/*                                  │
  │                                                                   │
  │   getSession(request) -> Bearer Token OR Session Cookie          │
  └──────────────────────────────────────────────────────────────────┘
```

## OAuth Provider Endpoints

| Endpoint | Purpose |
|----------|---------|
| `/api/oauth/authorize` | User authorization |
| `/api/oauth/token` | Token exchange & refresh |
| `/api/oauth/userinfo` | User profile |
| `/.well-known/openid-configuration` | OIDC discovery |

## OAuth Scopes

| Scope | Purpose |
|-------|---------|
| `openid` | Required for OIDC |
| `email` | User's email address |
| `profile` | User's name and picture |
| `offline_access` | Enables refresh tokens |

## Key Files

| Component | Path |
|-----------|------|
| Backend Auth Config | `{backend}/auth.ts` |
| Bearer Token Helper | `{backend}/lib/auth-helper.ts` |
| Route Middleware | `{backend}/proxy.ts` |
| iOS Debug Config | `{iOS-Project}/Config/Debug.xcconfig` |
| iOS Release Config | `{iOS-Project}/Config/Release.xcconfig` |
| iOS Secrets | `{iOS-Project}/Config/Secrets.xcconfig` |
| iOS OAuth Manager | `{Core-Package}/Authentication/OAuthManager.swift` |
| iOS Token Storage | `{Core-Package}/Authentication/TokenStorage.swift` |
| iOS API Middleware | `{Core-Package}/Networking/AuthenticationMiddleware.swift` |
