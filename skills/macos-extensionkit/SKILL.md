---
name: macos-extensionkit
description: Build a macOS app that hosts its own in-app UI extension using Apple's ExtensionKit / ExtensionFoundation (AppExtension, AppExtensionPoint, EXHostViewController, NSXPC). Use when creating a host app + bundled app-extension target, defining a custom extension point, sharing an API/XPC contract core between host and extension, embedding extension SwiftUI inside the host, wiring bidirectional host↔extension messaging, or debugging extension discovery/activation failures (OSStatus -10814, "Failed to get extension process and XPC endpoints", LSRegisterURL -10819).
---

## Overview

This skill builds a macOS app with a **first-party in-app extension** using Apple's modern **ExtensionKit / ExtensionFoundation** frameworks (the `AppExtension` / `AppExtensionPoint` / `EXHostViewController` API family — *not* the legacy `NSExtension` Info.plist style). The host app defines its own custom extension point, discovers and activates a bundled extension, embeds the extension's SwiftUI inside the host window, and exchanges messages with it over `NSXPCConnection`.

The architecture has three pieces:

| Piece | Role |
|-------|------|
| **Host app target** | Defines the static extension point, discovers identities, embeds extension UI via `EXHostViewController`, vends the host XPC API |
| **Extension target** (`.appex`) | Conforms to `AppExtension`, presents SwiftUI through a scene, vends the extension XPC API |
| **`core` Swift package** | Shared module linked into **both** — holds constants, the `@objc` XPC protocols, and shared models so the contract is defined once |

Read `references/architecture.md` for the project layout, the shared `core` package, and the Makefile build/stage flow.

## The non-negotiable rules (read first)

These are the steps that, when missed, cause silent discovery/activation failures. Do them in order.

1. Create a shared `core` Swift package and link it into **both** the host and extension targets.
2. Put the XPC protocols (`@objc`, `NSObjectProtocol`) and shared constants in `core` — define the contract once.
3. Declare the extension point as a **static** `@Definition` in a **host-target** source file (not as an instance property on the `App` struct).
4. Set `EX_ENABLE_EXTENSION_POINT_GENERATION = YES` on **host AND extension**, for **both Debug and Release**.
5. Add `EXExtensionPointIdentifier` under `EXAppExtensionAttributes` in the extension's Info.plist.
6. In the extension entry point use **direct `AppExtension` conformance** + a direct `AppExtensionSceneConfiguration`. Custom wrapper-protocol conformance compiles and discovers but **fails activation**.
7. Use the **same `sceneID`** in `PrimitiveAppExtensionScene` and `EXHostViewController.Configuration`.
8. Build the **host scheme** (not the extension alone), with **signing enabled**.
9. Stage both the `.app` and the `.appex`.
10. **Quit and relaunch** the rebuilt host after any change to extension metadata or the entry point — a running host keeps stale `.appexpt` metadata.

## Workflow: Set Up Structure & Shared Core

### Step 1: Lay out the targets

```text
Makefile
core/                      # shared Swift package
  Package.swift
  Sources/core/core.swift
test-app-extension/        # host app target sources
  test_app_extensionApp.swift
  ContentView.swift
  SampleExtensionPoint.swift
test-ui-extension/         # extension (.appex) target sources
  Info.plist
  test_ui_extension.swift
test-app-extension.xcodeproj/
```

### Step 2: Create the `core` package and the XPC contract

`core` holds the constants and the two `@objc` protocols. Both must be `@objc` + `NSObjectProtocol`, or `NSXPCInterface(with:)` cannot bind the same contract on both sides.

Link `core` as a package product dependency on **both** the host target and the extension target.

Read `references/architecture.md` for the full `Package.swift`, the `core` contents, and the Makefile.

## Workflow: Define & Load the Extension Point

### Step 1: Static host extension point

In a **host-target** file (`SampleExtensionPoint.swift`):

```swift
import ExtensionFoundation

extension AppExtensionPoint {
    @Definition
    static var sampleUIExtension: AppExtensionPoint {
        Name("ui-extension")
        UserInterface()
    }
}
```

### Step 2: Enable metadata generation

Set `EX_ENABLE_EXTENSION_POINT_GENERATION = YES` for Debug + Release on host **and** extension targets. This makes the build run `ExtensionPointExtractor`, which emits the host bundle's `Contents/Extensions/<host>.appexpt` describing the extension point. Without it, `AppExtensionPoint(identifier:)` fails with `OSStatus -10814`.

### Step 3: Extension Info.plist + discovery

Add `EXExtensionPointIdentifier` to the extension plist, then discover at runtime with `AppExtensionPoint.Monitor`.

Read `references/extension-point-and-loading.md` for the plist, bundle IDs, sandbox/entitlement settings, the `Monitor` discovery code, and the LaunchServices "load from disk" flow.

## Workflow: Build the Extension Entry Point

Use **direct `AppExtension` conformance**. Required imports: `ExtensionFoundation`, `ExtensionKit`, `SwiftUI`, and `core`. Bridge the SwiftUI content with `PrimitiveAppExtensionScene`, handing its `onConnection` to the extension's XPC bridge.

Read `references/extension-point-and-loading.md` (section "Extension entry point") for the verbatim `test_ui_extension.swift` and the `SampleUIScene` bridge, plus *why* the wrapper-protocol approach broke activation.

## Workflow: Wire Host ↔ Extension Communication

### Step 1: Embed extension UI

Wrap `EXHostViewController` in an `NSViewControllerRepresentable`, set its `.configuration` to `.init(appExtension: identity, sceneID:)`, and assign a delegate.

### Step 2: Get the XPC connection on activation

In `hostViewControllerDidActivate`, call `viewController.makeXPCConnection()`. The host **can only send messages after this succeeds and the remote proxy is non-nil** — the "loaded but cannot send message" state means discovery worked but activation/XPC did not.

### Step 3: Symmetric XPC setup

Host exports `SampleHostAPI` / remote-interfaces `SampleExtensionAPI`; the extension's scene `onConnection` does the mirror image. Both `resume()` and grab a `remoteObjectProxyWithErrorHandler`.

Read `references/communication.md` for the full host controller, the symmetric XPC configuration on both sides, and the end-to-end message-flow sequence.

## Troubleshooting

Read `references/troubleshooting.md` for the observed failure modes and fixes: `OSStatus -10814` (missing `.appexpt`), `LSRegisterURL -10819` (non-fatal LaunchServices warning), "Failed to get extension process and XPC endpoints" / "Host session request returned nil" (activation failure → direct conformance fix), ViewBridge Code=18, signing requirements, and the relaunch-after-rebuild rule.
