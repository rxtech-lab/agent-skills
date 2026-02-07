# iOS Authentication Reference (Swift)

## Table of Contents

- [iOS Libraries](#ios-libraries)
- [xcconfig Configuration](#xcconfig-configuration)
- [AppConfiguration](#appconfiguration)
- [OAuthManager (PKCE)](#oauthmanager-pkce)
- [Token Storage (Keychain)](#token-storage-keychain)
- [Authentication Middleware](#authentication-middleware)
- [Token Refresh](#token-refresh)
- [SwiftUI Integration](#swiftui-integration)

## iOS Libraries

No third-party OAuth libraries required. Uses Apple native frameworks:

| Framework | Purpose |
|-----------|---------|
| `AuthenticationServices` | `ASWebAuthenticationSession` for OAuth |
| `Security` | Keychain for secure token storage |
| `CryptoKit` | SHA256 for PKCE code challenge |

## xcconfig Configuration

### Debug.xcconfig

```bash
#include "Secrets.xcconfig"

API_BASE_URL = http:/$()/localhost:3000
AUTH_ISSUER = https://{auth-domain}
AUTH_REDIRECT_URI = {app-scheme}://oauth/callback
AUTH_SCOPES = openid email profile offline_access
AUTH_CLIENT_ID = $(AUTH_CLIENT_ID_DEV)
```

### Release.xcconfig

```bash
#include "Secrets.xcconfig"

API_BASE_URL = https://$()/{production-domain}
AUTH_ISSUER = https://{auth-domain}
AUTH_REDIRECT_URI = {app-scheme}://oauth/callback
AUTH_SCOPES = openid email profile offline_access
AUTH_CLIENT_ID = $(AUTH_CLIENT_ID_PROD)
```

### Secrets.xcconfig (git-ignored)

```bash
AUTH_CLIENT_ID_DEV = client_dev_xxxxxxxxxxxx
AUTH_CLIENT_ID_PROD = client_prod_xxxxxxxxxxxx
```

### Info.plist Variable Substitution

Add these keys to Info.plist so values from xcconfig are available at runtime:

```xml
<key>API_BASE_URL</key>
<string>$(API_BASE_URL)</string>
<key>AUTH_CLIENT_ID</key>
<string>$(AUTH_CLIENT_ID)</string>
<key>AUTH_ISSUER</key>
<string>$(AUTH_ISSUER)</string>
<key>AUTH_REDIRECT_URI</key>
<string>$(AUTH_REDIRECT_URI)</string>
<key>AUTH_SCOPES</key>
<string>$(AUTH_SCOPES)</string>
```

### URL Scheme Registration in Info.plist

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>{app-scheme}</string>
        </array>
        <key>CFBundleURLName</key>
        <string>{bundle-identifier}</string>
    </dict>
</array>
```

## AppConfiguration

File: `{Core-Package}/Configuration/AppConfiguration.swift`

```swift
import Foundation

@Observable
public class AppConfiguration {
    public static let shared = AppConfiguration()

    public let apiBaseURL: String
    public let authIssuer: String
    public let authClientID: String
    public let authRedirectURI: String
    public let authScopes: [String]

    private init() {
        let bundle = Bundle.main
        let info = bundle.infoDictionary

        self.apiBaseURL = info?["API_BASE_URL"] as? String
            ?? "http://localhost:3000"

        self.authIssuer = info?["AUTH_ISSUER"] as? String
            ?? "https://{auth-domain}"

        self.authClientID = info?["AUTH_CLIENT_ID"] as? String
            ?? ""

        self.authRedirectURI = info?["AUTH_REDIRECT_URI"] as? String
            ?? "{app-scheme}://oauth/callback"

        let scopesString = info?["AUTH_SCOPES"] as? String
            ?? "openid email profile offline_access"
        self.authScopes = scopesString.components(separatedBy: " ")
    }
}
```

## OAuthManager (PKCE)

File: `{Core-Package}/Authentication/OAuthManager.swift`

```swift
import Foundation
import AuthenticationServices
import CryptoKit

@Observable
public final class OAuthManager: NSObject {
    public static let shared = OAuthManager()

    public enum AuthenticationState {
        case unknown
        case authenticated
        case unauthenticated
    }

    public private(set) var authState: AuthenticationState = .unknown
    public private(set) var currentUser: User?

    private let config = AppConfiguration.shared
    private let tokenStorage = TokenStorage.shared
    private var codeVerifier: String?

    // MARK: - Authentication

    public func authenticate() async throws {
        let verifier = generateCodeVerifier()
        self.codeVerifier = verifier
        let challenge = generateCodeChallenge(from: verifier)

        var components = URLComponents(string: "\(config.authIssuer)/api/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.authClientID),
            URLQueryItem(name: "redirect_uri", value: config.authRedirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.authScopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        guard let authURL = components.url else {
            throw OAuthError.invalidURL
        }

        let callbackURL = try await launchWebAuthentication(url: authURL)

        guard let code = extractCode(from: callbackURL) else {
            throw OAuthError.noAuthorizationCode
        }

        try await exchangeCodeForTokens(code: code, verifier: verifier)
        try await fetchUserInfo()
        authState = .authenticated
    }

    // MARK: - Web Authentication Session

    private func launchWebAuthentication(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "{app-scheme}"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let callbackURL = callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: OAuthError.noCallback)
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    // MARK: - Token Exchange

    private func exchangeCodeForTokens(code: String, verifier: String) async throws {
        let tokenURL = URL(string: "\(config.authIssuer)/api/oauth/token")!

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": config.authRedirectURI,
            "client_id": config.authClientID,
            "code_verifier": verifier,
        ]

        request.httpBody = params
            .map { "\($0.key)=\($0.value.urlEncoded)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OAuthError.tokenExchangeFailed
        }

        let tokens = try JSONDecoder().decode(TokenResponse.self, from: data)

        await tokenStorage.saveAccessToken(tokens.accessToken)
        await tokenStorage.saveRefreshToken(tokens.refreshToken)

        let expiresAt = Date().addingTimeInterval(TimeInterval(tokens.expiresIn))
        await tokenStorage.saveExpiresAt(expiresAt)
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }

    // MARK: - Sign Out

    public func signOut() async {
        await tokenStorage.clearAll()
        authState = .unauthenticated
        currentUser = nil
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension OAuthManager: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        #else
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
        #endif
    }
}

// MARK: - Supporting Types

struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

enum OAuthError: Error {
    case invalidURL
    case noCallback
    case noAuthorizationCode
    case tokenExchangeFailed
    case userInfoFailed
    case noRefreshToken
    case refreshFailed
}
```

## Token Storage (Keychain)

File: `{Core-Package}/Authentication/TokenStorage.swift`

```swift
import Foundation
import Security

public actor TokenStorage {
    public static let shared = TokenStorage()

    private let service = "{bundle-identifier}"

    private enum Keys {
        static let accessToken = "accessToken"
        static let refreshToken = "refreshToken"
        static let expiresAt = "expiresAt"
    }

    public func saveAccessToken(_ token: String) {
        save(key: Keys.accessToken, value: token)
    }

    public func getAccessToken() -> String? {
        return get(key: Keys.accessToken)
    }

    public func saveRefreshToken(_ token: String?) {
        if let token = token {
            save(key: Keys.refreshToken, value: token)
        }
    }

    public func getRefreshToken() -> String? {
        return get(key: Keys.refreshToken)
    }

    public func saveExpiresAt(_ date: Date) {
        let timestamp = String(date.timeIntervalSince1970)
        save(key: Keys.expiresAt, value: timestamp)
    }

    public func getExpiresAt() -> Date? {
        guard let timestamp = get(key: Keys.expiresAt),
              let interval = Double(timestamp) else {
            return nil
        }
        return Date(timeIntervalSince1970: interval)
    }

    public func isTokenExpired() -> Bool {
        guard let expiresAt = getExpiresAt() else { return true }
        return Date().addingTimeInterval(600) >= expiresAt
    }

    public func clearAll() {
        delete(key: Keys.accessToken)
        delete(key: Keys.refreshToken)
        delete(key: Keys.expiresAt)
    }

    // MARK: - Keychain Operations

    private func save(key: String, value: String) {
        let data = value.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        SecItemDelete(query as CFDictionary)

        var newItem = query
        newItem[kSecValueData as String] = data
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        SecItemAdd(newItem as CFDictionary, nil)
    }

    private func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        SecItemDelete(query as CFDictionary)
    }
}
```

## Authentication Middleware

File: `{Core-Package}/Networking/AuthenticationMiddleware.swift`

```swift
import Foundation
import OpenAPIRuntime
import HTTPTypes

public struct AuthenticationMiddleware: ClientMiddleware {
    private let tokenStorage = TokenStorage.shared
    private let oauthManager = OAuthManager.shared

    public init() {}

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {

        var modifiedRequest = request

        if let token = await tokenStorage.getAccessToken() {
            modifiedRequest.headerFields[.authorization] = "Bearer \(token)"
        }

        let (response, responseBody) = try await next(modifiedRequest, body, baseURL)

        if response.status == .unauthorized {
            if await tokenStorage.getRefreshToken() != nil {
                try await oauthManager.refreshToken()

                if let newToken = await tokenStorage.getAccessToken() {
                    modifiedRequest.headerFields[.authorization] = "Bearer \(newToken)"
                    return try await next(modifiedRequest, body, baseURL)
                }
            }

            NotificationCenter.default.post(name: .authSessionExpired, object: nil)
        }

        return (response, responseBody)
    }
}

extension Notification.Name {
    public static let authSessionExpired = Notification.Name("authSessionExpired")
}
```

## Token Refresh

```swift
// Add to OAuthManager
public func refreshToken() async throws {
    guard let refreshToken = await tokenStorage.getRefreshToken() else {
        throw OAuthError.noRefreshToken
    }

    let tokenURL = URL(string: "\(config.authIssuer)/api/oauth/token")!

    var request = URLRequest(url: tokenURL)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

    let params = [
        "grant_type": "refresh_token",
        "refresh_token": refreshToken,
        "client_id": config.authClientID,
    ]

    request.httpBody = params
        .map { "\($0.key)=\($0.value.urlEncoded)" }
        .joined(separator: "&")
        .data(using: .utf8)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw OAuthError.refreshFailed
    }

    let tokens = try JSONDecoder().decode(TokenResponse.self, from: data)

    await tokenStorage.saveAccessToken(tokens.accessToken)
    if let newRefreshToken = tokens.refreshToken {
        await tokenStorage.saveRefreshToken(newRefreshToken)
    }

    let expiresAt = Date().addingTimeInterval(TimeInterval(tokens.expiresIn))
    await tokenStorage.saveExpiresAt(expiresAt)
}
```

## SwiftUI Integration

### Root View (Auth State Routing)

```swift
struct ContentView: View {
    var authManager = OAuthManager.shared

    var body: some View {
        Group {
            switch authManager.authState {
            case .unknown:
                ProgressView("Loading...")
            case .authenticated:
                MainTabView()
            case .unauthenticated:
                LoginView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .authSessionExpired)) { _ in
            Task {
                await authManager.signOut()
            }
        }
    }
}
```

### Login View

```swift
struct LoginView: View {
    var authManager = OAuthManager.shared
    @State private var isLoading = false
    @State private var error: Error?

    var body: some View {
        VStack(spacing: 24) {
            Image("AppIcon")
                .resizable()
                .frame(width: 120, height: 120)

            Text("{App Name}")
                .font(.largeTitle.bold())

            Button {
                Task {
                    isLoading = true
                    defer { isLoading = false }
                    do {
                        try await authManager.authenticate()
                    } catch {
                        self.error = error
                    }
                }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                    }
                    Text("Sign In with {Provider}")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isLoading)
        }
        .padding()
        .alert("Authentication Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error?.localizedDescription ?? "")
        }
    }
}
```
