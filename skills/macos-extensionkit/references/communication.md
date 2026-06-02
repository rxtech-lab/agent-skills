# Host ↔ Extension Communication (Embedding + XPC)

The host embeds a **known** extension identity with `EXHostViewController` (not the picker-style `EXAppExtensionBrowserViewController`), then talks to it over `NSXPCConnection` using the protocols defined in `core`.

## 1. Embed the extension UI

Wrap `EXHostViewController` in an `NSViewControllerRepresentable`:

```swift
struct ExtensionHostController: NSViewControllerRepresentable {
    let identity: AppExtensionIdentity
    let model: ExtensionHostModel

    func makeNSViewController(context: Context) -> EXHostViewController {
        let viewController = EXHostViewController()
        viewController.delegate = context.coordinator
        viewController.configuration = .init(
            appExtension: identity,
            sceneID: SampleExtensionConstants.sceneID   // must match the extension's scene id
        )
        return viewController
    }
}
```

## 2. Get the XPC connection on activation

The host obtains its connection in the delegate's activation callback. **This is the gate for messaging** — the host cannot send anything until `makeXPCConnection()` succeeds.

```swift
func hostViewControllerDidActivate(_ viewController: EXHostViewController) {
    do {
        let connection = try viewController.makeXPCConnection()
        model.configure(connection: connection)
    } catch {
        model.deactivateConnection(error: error)
    }
}
```

## 3. Symmetric XPC configuration

Both sides configure the **same** connection object, mirrored: each side *exports* its own API and sets the *remote interface* to the other side's API.

Host side:

```swift
newConnection.exportedInterface = NSXPCInterface(with: SampleHostAPI.self)
newConnection.exportedObject = hostAPI
newConnection.remoteObjectInterface = NSXPCInterface(with: SampleExtensionAPI.self)
newConnection.resume()

remoteExtension = newConnection.remoteObjectProxyWithErrorHandler { error in
    // log proxy error
} as? SampleExtensionAPI
```

Extension side (invoked from the scene's `onConnection`):

```swift
func accept(connection: NSXPCConnection) -> Bool {
    connection.exportedInterface = NSXPCInterface(with: SampleExtensionAPI.self)
    connection.exportedObject = self
    connection.remoteObjectInterface = NSXPCInterface(with: SampleHostAPI.self)
    connection.resume()

    remoteHost = connection.remoteObjectProxyWithErrorHandler { error in
        // log proxy error
    } as? SampleHostAPI

    sendMessageToHost("Extension UI connected")
    return true
}
```

## 4. Message flow

```text
Host EXHostViewController activates
Host calls makeXPCConnection()
Host exports SampleHostAPI
Extension scene onConnection exports SampleExtensionAPI
Host calls   remoteExtension.hostDidSendMessage(...)      // host → extension
Extension calls remoteHost.extensionDidSendMessage(...)   // extension → host
```

Each call carries a `withReply:` closure, so both directions support request/response.

## 5. "Loaded but cannot send message"

This symptom means **identity discovery succeeded but activation/XPC did not**. The extension UI may even render, yet `remoteExtension` is `nil`.

Checklist when you see it:

- Did `hostViewControllerDidActivate` fire, and did `makeXPCConnection()` throw?
- Is the extension using **direct `AppExtension` conformance**? (A wrapper protocol passes discovery but fails activation — see `extension-point-and-loading.md`.)
- Do the host `sceneID` and the extension's `PrimitiveAppExtensionScene` id match exactly?
- Are both protocols `@objc` / `NSObjectProtocol` and defined in shared `core`?
- Was the host **relaunched** after the last rebuild?

The host may only send after `makeXPCConnection()` succeeds **and** `remoteExtension` is non-nil.
