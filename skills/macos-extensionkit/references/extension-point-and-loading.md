# Extension Point, Config, Loading & Entry Point

## 1. The static host extension point

The extension-point definition **must live in a host-target source file** and be a **static** `@Definition`. Putting it as an instance property on the `App` struct compiles but does **not** generate the metadata.

`test-app-extension/SampleExtensionPoint.swift`:

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

The resulting identifier is `<host-bundle-id>.<name>` → `rxlab.test-app-extension.ui-extension`.

## 2. Critical build setting

```text
EX_ENABLE_EXTENSION_POINT_GENERATION = YES
```

Set it for **Debug and Release** on **both** targets:

```text
test-app-extension   (host)
test-ui-extension    (extension)
```

When enabled, the build runs `ExtensionPointExtractor` and emits the metadata into the host bundle:

```text
test-app-extension.app/Contents/Extensions/test_app_extension.appexpt
```

That `.appexpt` contains the extension point:

```xml
<key>rxlab.test-app-extension.ui-extension</key>
<dict>
  <key>EXExtensionPointName</key>
  <string>ui-extension</string>
  <key>EXPresentsUserInterface</key>
  <true/>
</dict>
```

Without this file, `AppExtensionPoint(identifier:)` fails with **`OSStatus -10814`**. Verifying that `ExtensionPointExtractor` ran during the build, and that the `.appexpt` exists in the staged app, is the fastest way to confirm this step.

## 3. Bundle IDs, plist & entitlements

Extension Info.plist (`test-ui-extension/Info.plist`):

```xml
<key>EXAppExtensionAttributes</key>
<dict>
  <key>EXExtensionPointIdentifier</key>
  <string>rxlab.test-app-extension.ui-extension</string>
</dict>
```

Host build settings:

```text
PRODUCT_BUNDLE_IDENTIFIER = rxlab.test-app-extension
ENABLE_APP_SANDBOX = YES
ENABLE_USER_SELECTED_FILES = readonly      # needed for the "load from disk" picker
```

Extension build settings:

```text
PRODUCT_BUNDLE_IDENTIFIER = rxlab.test-app-extension.test-ui-extension
INFOPLIST_FILE = test-ui-extension/Info.plist
ENABLE_APP_SANDBOX = YES
```

The extension bundle id is conventionally a child of the host bundle id.

## 4. Runtime discovery

Discover identities for the extension point with `AppExtensionPoint.Monitor`:

```swift
let point = try AppExtensionPoint(identifier: "rxlab.test-app-extension.ui-extension")
monitor = try await AppExtensionPoint.Monitor(appExtensionPoint: point)
let identities = monitor?.identities ?? []
```

A successful run logs something like `Monitor found 1 identity(s)`. Each `AppExtensionIdentity` is what you hand to `EXHostViewController` to activate (see `communication.md`).

## 5. "Load extension from disk" (LaunchServices)

The disk picker does **not** directly load an arbitrary `.appex` by URL. Instead it:

1. Registers candidate bundles with LaunchServices.
2. Refreshes identities via the monitor.
3. Matches the selected `.appex` bundle id against discovered identities.

`LSRegisterURL` is best-effort — log failures and continue:

```swift
let status = LSRegisterURL(candidate as CFURL, true)
if status == noErr {
    log("Registered \(candidate.lastPathComponent)")
} else {
    log("LaunchServices registration warning: OSStatus \(status)")
}
```

`OSStatus -10819` occurs often here and is **not fatal** — rely on monitor discovery afterward.

> Standalone `.appex` selection is a convenience. The reliable path is registering/discovering the **signed provider app** that contains the extension and its `.appexpt`, then matching the selected extension's bundle id.

## 6. Extension entry point

Final working shape, `test-ui-extension/test_ui_extension.swift`:

```swift
import Combine
import ExtensionFoundation
import ExtensionKit
import Foundation
import SwiftUI
import core

@main
struct test_ui_extension: AppExtension {
    @AppExtensionPoint.Bind
    var extensionPoint: AppExtensionPoint {
        AppExtensionPoint.Identifier(
            host: "rxlab.test-app-extension",
            name: "ui-extension"
        )
    }

    var configuration: AppExtensionSceneConfiguration {
        AppExtensionSceneConfiguration(
            SampleUIScene(onConnection: ExtensionBridge.shared.accept(connection:)) {
                ExtensionContentView()
            }
        )
    }
}
```

### Why direct conformance matters

An earlier version wrapped `AppExtension` in a custom protocol defined in `core`. It **compiled and discovery worked**, but activation failed with:

```text
Host session request returned nil
Failed to get extension process and XPC endpoints
Invalidated by remote connection
```

Switching to **direct `AppExtension` conformance** plus a **direct `AppExtensionSceneConfiguration`** fixed the activation path. Do not abstract the entry point behind a wrapper protocol.

`ExtensionKit` must be imported (in addition to `ExtensionFoundation`) for `AppExtensionSceneConfiguration`.

### The SwiftUI ↔ XPC scene bridge

The scene wraps content in `PrimitiveAppExtensionScene`, using the shared `sceneID` and forwarding `onConnection` to the extension's XPC bridge:

```swift
public struct SampleUIScene<Content: View>: SampleAppExtensionScene {
    public var body: some AppExtensionScene {
        PrimitiveAppExtensionScene(id: SampleExtensionConstants.sceneID) {
            content()
        } onConnection: { connection in
            connectionHandler(connection)
        }
    }
}
```

The `id` here **must equal** the `sceneID` used by the host's `EXHostViewController.Configuration`, or the host activates a scene the extension never vended.
