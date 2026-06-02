# Architecture: Structure & Shared Core

## Repo layout

```text
Makefile
core/
  Package.swift
  Sources/core/core.swift
  Tests/coreTests/coreTests.swift
test-app-extension/            # host app target
  ContentView.swift
  SampleExtensionPoint.swift
  test_app_extensionApp.swift
test-ui-extension/             # extension (.appex) target
  Info.plist
  test_ui_extension.swift
test-app-extension.xcodeproj/
```

Three logical units:

- **Host app** (`test-app-extension`) — owns the extension-point definition, discovers/activates extensions, embeds their UI, vends the host XPC API.
- **Extension** (`test-ui-extension`, an `.appex`) — conforms to `AppExtension`, presents SwiftUI, vends the extension XPC API.
- **`core`** — a Swift package linked into **both** targets so the API/XPC contract lives in exactly one place.

## The shared `core` package

`core/Package.swift`:

```swift
let package = Package(
    name: "core",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "core", targets: ["core"]),
    ],
    targets: [
        .target(name: "core"),
        .testTarget(name: "coreTests", dependencies: ["core"]),
    ]
)
```

Link `core` into **both** the host target and the extension target via the Xcode package **product dependency** (General → Frameworks, Libraries, and Embedded Content / "Add Package Dependency" → local package). Do not copy the protocol files into each target — that defeats the purpose and the XPC interfaces will silently fail to bind.

### What lives in `core`

Shared constants and the two XPC protocols:

```swift
public enum SampleExtensionConstants {
    public static let hostBundleIdentifier: StaticString = "rxlab.test-app-extension"
    public static let extensionPointName: StaticString = "ui-extension"
    public static let extensionPointIdentifier = "rxlab.test-app-extension.ui-extension"
    public static let extensionBundleIdentifier = "rxlab.test-app-extension.test-ui-extension"
    public static let sceneID = "sample-ui-scene"
}

@objc public protocol SampleHostAPI: NSObjectProtocol {
    func extensionDidSendMessage(_ message: String, withReply reply: @escaping (String) -> Void)
}

@objc public protocol SampleExtensionAPI: NSObjectProtocol {
    func hostDidSendMessage(_ message: String, withReply reply: @escaping (String) -> Void)
}
```

**Why `@objc` + `NSObjectProtocol`:** `NSXPCInterface(with:)` requires an Objective-C-visible protocol. If the protocol is a pure-Swift protocol, the interface cannot bind the same contract on both sides of the connection and messaging fails at runtime even though everything compiles.

**Centralize the `sceneID` and identifiers as constants.** The same `sceneID` string must be used by `PrimitiveAppExtensionScene` (extension side) and `EXHostViewController.Configuration` (host side); a single constant prevents drift.

## Makefile

`make extension` builds the **host scheme** (so the provider app and its generated metadata are produced), then stages both artifacts:

```make
extension:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(APP_SCHEME) \
		-configuration $(CONFIGURATION) \
		-derivedDataPath $(DERIVED_DATA) \
		build
	mkdir -p $(EXTENSION_OUTPUT)
	rm -rf $(STAGED_APP)
	rm -rf $(STAGED_EXTENSION)
	cp -R $(BUILT_APP) $(STAGED_APP)
	cp -R $(BUILT_EXTENSION) $(STAGED_EXTENSION)
```

Key point: **build the host app scheme, not just the extension.** The provider app and the generated `.appexpt` metadata are what discovery/activation rely on.

`make test` runs the package tests:

```make
test:
	swift test --package-path core
```

UI tests were intentionally skipped in this repo. Keep the testable, side-effect-free logic (models, message encoding, constants) in `core` so it can be unit-tested without a running host.
