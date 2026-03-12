# Sparkle Integration

## Table of Contents

- [Info.plist Configuration](#infoplist-configuration)
- [Swift App Entry Point](#swift-app-entry-point)
- [SPM Dependency](#spm-dependency)
- [Binary: generate_appcast](#binary-generate_appcast)

## Info.plist Configuration

Add these entries to your macOS app's `Info.plist`:

```xml
<key>SUEnableInstallerLauncherService</key>
<true/>
<key>SUFeedURL</key>
<string>https://update.linda.rxlab.app/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_ED_KEY_HERE</string>
```

| Key | Purpose |
|-----|---------|
| `SUEnableInstallerLauncherService` | Enable Sparkle's installer launcher XPC service |
| `SUFeedURL` | URL to the appcast.xml feed (hosted on GitHub Pages) |
| `SUPublicEDKey` | EdDSA public key for verifying update signatures |

The public key is generated alongside the private key using `bin/generate_keys` from Sparkle. The private key becomes the `SPARKLE_KEY` GitHub secret; the public key goes into `Info.plist`.

## Swift App Entry Point

Import Sparkle conditionally for macOS and initialize the updater controller:

```swift
#if os(macOS)
    import Sparkle
#endif

#if os(macOS)
    private var updaterController: SPUStandardUpdaterController?
#endif

@main
struct iosApp: App {
    init() {
        #if os(macOS)
            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        #endif
    }

    var body: some Scene {
        WindowGroup { /* ... */ }
        #if os(macOS)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updaterController?.checkForUpdates(nil)
                }
            }
        }
        #endif
    }
}
```

Key points:

- Use `#if os(macOS)` guards since Sparkle is macOS-only
- `SPUStandardUpdaterController(startingUpdater: true, ...)` starts checking for updates on launch
- The "Check for Updates..." menu item is added to the app menu after "About"
- `updaterController` is stored as a property to keep the controller alive

## SPM Dependency

Add Sparkle via Swift Package Manager in Xcode:

1. File → Add Package Dependencies
2. Enter URL: `https://github.com/sparkle-project/Sparkle`
3. Set platform filter to **macOS only**
4. Add to your macOS app target

Or add directly to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
]
```

With a target dependency filtered to macOS:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "Sparkle", package: "Sparkle", condition: .when(platforms: [.macOS]))
    ]
)
```

## Binary: generate_appcast

The `generate_appcast` binary from the Sparkle project is checked into the repo at `bin/generate_appcast`. It:

- Scans a directory for DMG files
- Generates `appcast.xml` with EdDSA signatures
- Uses the private key provided via environment or key file
- Creates download URLs based on the GitHub Release assets

This binary is used by `scripts/generate-appcast.sh` during CI to produce the appcast feed.
