# Troubleshooting Reference

## Common Issues

### "Invalid client" error during authentication

- Verify `AUTH_CLIENT_ID` matches the OAuth provider configuration
- Ensure redirect URI is registered with the OAuth provider
- Check that the correct client ID is used for the environment (dev vs prod)

### 401 Unauthorized on API requests

- Check that Bearer token is being sent in Authorization header
- Verify token hasn't expired (check `expiresAt`)
- Ensure backend `getSession()` is receiving the `request` parameter
- Verify the OAuth provider's userinfo endpoint is reachable

### Token refresh failing

- Verify `offline_access` scope is included in the authorization request
- Check refresh token hasn't been revoked by the provider
- Ensure `AUTH_CLIENT_SECRET` is correct (backend only)
- Check network connectivity to the token endpoint

### iOS: "Secrets.xcconfig not found"

```bash
cd {iOS-Project}/Config
cp Secrets.xcconfig.example Secrets.xcconfig
# Edit with your OAuth client IDs
```

### iOS: URL scheme not working

- Verify `{app-scheme}` is registered in Info.plist under `CFBundleURLSchemes`
- Check callback URL matches exactly: `{app-scheme}://oauth/callback`
- Ensure the scheme is unique and not conflicting with other apps

### iOS: ASWebAuthenticationSession not presenting

- Verify `presentationContextProvider` is set before calling `start()`
- Check that the presenting window scene is active
- On macOS, ensure `NSApplication.shared.windows` has at least one window

## Debug Logging

### Backend

```typescript
// Add to getSession() for debugging
console.log('Session:', await getSession(request));
console.log('Bearer token:', getBearerToken(request));
console.log('Auth header:', request.headers.get('authorization'));
```

### iOS

```swift
#if DEBUG
print("Token expires at: \(await tokenStorage.getExpiresAt())")
print("Is expired: \(await tokenStorage.isTokenExpired())")
print("Has refresh token: \(await tokenStorage.getRefreshToken() != nil)")
print("Auth state: \(authManager.authState)")
#endif
```

## Environment Variable Checklist

### Backend (.env)

| Variable | Required | Description |
|----------|----------|-------------|
| `AUTH_SECRET` | Yes | Session encryption key |
| `AUTH_ISSUER` | Yes | OAuth provider URL |
| `AUTH_CLIENT_ID` | Yes | OAuth client ID |
| `AUTH_CLIENT_SECRET` | Yes | OAuth client secret |
| `IS_E2E` | No | Set to `"true"` for test mode |

### iOS (Secrets.xcconfig)

| Variable | Required | Description |
|----------|----------|-------------|
| `AUTH_CLIENT_ID_DEV` | Yes | Development OAuth client ID |
| `AUTH_CLIENT_ID_PROD` | Yes | Production OAuth client ID |
