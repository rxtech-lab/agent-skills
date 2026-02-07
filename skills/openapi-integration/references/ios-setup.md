# iOS Setup (Swift OpenAPI Generator)

## Table of Contents
- [Package.swift Dependencies](#packageswift-dependencies)
- [Generator Configuration](#generator-configuration)
- [Download the OpenAPI Spec](#download-the-openapi-spec)
- [File Structure](#file-structure)
- [What Gets Generated](#what-gets-generated)
- [API Client Setup](#api-client-setup)
- [Authentication Middleware](#authentication-middleware)
- [Service Layer Pattern](#service-layer-pattern)

## Package.swift Dependencies

Add to `<ios-app>/packages/<package-name>/Package.swift`:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "<PackageName>",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "<PackageName>", targets: ["<PackageName>"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "<PackageName>",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            path: "Sources/<PackageName>",
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
            ]
        ),
    ]
)
```

## Generator Configuration

Create `<ios-app>/packages/<package-name>/Sources/<package-name>/openapi-generator-config.yaml`:

```yaml
generate:
  - types    # Generates Components.Schemas structs
  - client   # Generates Client struct with API methods
accessModifier: public
```

## Download the OpenAPI Spec

```bash
./scripts/ios-download-openapi.sh <ios-app> <package-name>
```

The `openapi.json` file **must** be in the same directory as `openapi-generator-config.yaml`.

## File Structure

```
<ios-app>/packages/<package-name>/Sources/<package-name>/
├── openapi.json                    # Downloaded from backend (required)
├── openapi-generator-config.yaml   # Generator config (required)
├── Networking/
│   ├── StorageAPIClient.swift      # Configured API client
│   ├── AuthenticationMiddleware.swift
│   ├── LoggingMiddleware.swift
│   └── Services/
│       ├── ItemService.swift
│       ├── CategoryService.swift
│       └── ...
└── Models/
    └── ...                         # Model extensions/type aliases
```

## What Gets Generated

At build time, `swift-openapi-generator` creates in `.build/`:

- **Types.swift** — `Components.Schemas.*` structs for all request/response models
- **Client.swift** — `APIProtocol` and `Client` struct with typed methods per `operationId`

These are **never edited manually**. Consume them via the service layer.

### Generated types example

```swift
public enum Components {
    public enum Schemas {
        public struct ItemResponseSchema: Codable, Hashable, Sendable {
            public var id: Swift.Int
            public var userId: Swift.String
            public var title: Swift.String
            public var description: Swift.String?
            public var visibility: VisibilityPayload
            public var createdAt: Foundation.Date
            public var updatedAt: Foundation.Date

            public enum VisibilityPayload: String, Codable, Sendable {
                case publicAccess
                case privateAccess
            }
        }
    }
}
```

### Generated client example

```swift
public protocol APIProtocol: Sendable {
    func getItems(_ input: Operations.getItems.Input) async throws -> Operations.getItems.Output
    func createItem(_ input: Operations.createItem.Input) async throws -> Operations.createItem.Output
    // ... one method per operationId
}
```

## API Client Setup

Create `Networking/StorageAPIClient.swift`:

```swift
import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession

public final class StorageAPIClient: Sendable {
    public static let shared = StorageAPIClient()

    public let client: Client
    public let optionalAuthClient: Client

    private let configuration: AppConfiguration
    private let tokenStorage: TokenStorage

    public init(
        configuration: AppConfiguration = .shared,
        tokenStorage: TokenStorage = .shared
    ) {
        self.configuration = configuration
        self.tokenStorage = tokenStorage

        let joinedPath = configuration.apiBaseURL.hasSuffix("/api")
            ? configuration.apiBaseURL
            : configuration.apiBaseURL + "/api"
        let serverURL = URL(string: joinedPath)!

        // Handle ISO8601 dates with fractional seconds (.000Z)
        let clientConfiguration = Configuration(
            dateTranscoder: .iso8601WithFractionalSeconds
        )

        client = Client(
            serverURL: serverURL,
            configuration: clientConfiguration,
            transport: URLSessionTransport(),
            middlewares: [
                LoggingMiddleware(),
                AuthenticationMiddleware(tokenStorage: tokenStorage, configuration: configuration),
            ]
        )

        optionalAuthClient = Client(
            serverURL: serverURL,
            configuration: clientConfiguration,
            transport: URLSessionTransport(),
            middlewares: [
                LoggingMiddleware(),
                OptionalAuthMiddleware(tokenStorage: tokenStorage),
            ]
        )
    }
}
```

## Authentication Middleware

Create `Networking/AuthenticationMiddleware.swift`:

```swift
import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Adds Bearer token to all requests (required auth)
public actor AuthenticationMiddleware: ClientMiddleware {
    private let tokenStorage: TokenStorage
    private let configuration: AppConfiguration

    public init(tokenStorage: TokenStorage = .shared, configuration: AppConfiguration = .shared) {
        self.tokenStorage = tokenStorage
        self.configuration = configuration
    }

    public func intercept(
        _ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var modifiedRequest = request
        if let accessToken = await tokenStorage.getAccessToken() {
            modifiedRequest.headerFields[.authorization] = "Bearer \(accessToken)"
        }
        return try await next(modifiedRequest, body, baseURL)
    }
}

/// Adds Bearer token if available, does not require it
public actor OptionalAuthMiddleware: ClientMiddleware {
    private let tokenStorage: TokenStorage

    public init(tokenStorage: TokenStorage = .shared) {
        self.tokenStorage = tokenStorage
    }

    public func intercept(
        _ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var modifiedRequest = request
        if let accessToken = await tokenStorage.getAccessToken() {
            modifiedRequest.headerFields[.authorization] = "Bearer \(accessToken)"
        }
        return try await next(modifiedRequest, body, baseURL)
    }
}
```

## Service Layer Pattern

Wrap the generated client in service objects for cleaner app-level code.

Create `Networking/Services/ItemService.swift`:

```swift
import Foundation
import OpenAPIRuntime

public protocol ItemServiceProtocol: Sendable {
    func fetchItems(filters: ItemFilters?) async throws -> [StorageItem]
    func fetchItem(id: Int) async throws -> StorageItemDetail
    func createItem(_ request: NewItemRequest) async throws -> StorageItem
    func updateItem(id: Int, _ request: UpdateItemRequest) async throws -> StorageItem
    func deleteItem(id: Int) async throws
}

public struct ItemService: ItemServiceProtocol {
    public init() {}

    public func fetchItems(filters: ItemFilters?) async throws -> [StorageItem] {
        let query = Operations.getItems.Input.Query(
            cursor: filters?.cursor,
            limit: filters?.limit,
            search: filters?.search,
            categoryId: filters?.categoryId
        )

        let response = try await StorageAPIClient.shared.client.getItems(.init(query: query))

        switch response {
        case .ok(let okResponse):
            switch okResponse.body {
            case .json(let paginatedResponse):
                return paginatedResponse.data.map { StorageItem(from: $0) }
            }
        case .unauthorized:
            throw APIError.unauthorized
        case .undocumented(let statusCode, _):
            throw APIError.serverError("Unexpected status: \(statusCode)")
        }
    }

    public func createItem(_ request: NewItemRequest) async throws -> StorageItem {
        let response = try await StorageAPIClient.shared.client.createItem(
            .init(body: .json(request))
        )
        switch response {
        case .created(let createdResponse):
            switch createdResponse.body {
            case .json(let item): return StorageItem(from: item)
            }
        case .badRequest(let errorResponse):
            switch errorResponse.body {
            case .json(let error): throw APIError.badRequest(error.error)
            }
        case .unauthorized: throw APIError.unauthorized
        case .undocumented(let statusCode, _):
            throw APIError.serverError("Unexpected status: \(statusCode)")
        }
    }

    public func deleteItem(id: Int) async throws {
        let response = try await StorageAPIClient.shared.client.deleteItem(
            .init(path: .init(id: String(id)))
        )
        switch response {
        case .noContent: return
        case .unauthorized: throw APIError.unauthorized
        case .notFound: throw APIError.notFound
        case .undocumented(let statusCode, _):
            throw APIError.serverError("Unexpected status: \(statusCode)")
        }
    }

    // fetchItem and updateItem follow the same switch pattern
}
```
