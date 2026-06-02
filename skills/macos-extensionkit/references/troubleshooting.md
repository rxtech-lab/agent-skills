# Troubleshooting: Observed Failure Modes

These were all hit and resolved while getting this architecture working. They are ordered roughly by where they appear in the pipeline (discovery → activation → messaging).

## `OSStatus -10814` — extension point not found

**Symptom:** `AppExtensionPoint(identifier:)` throws `-10814`; no identities ever appear.

**Cause:** The host bundle is missing its generated extension-point metadata (`.appexpt`).

**Fix:**
- Declare the extension point as a **static** `@Definition` in a **host-target** file (not an instance property on the `App`).
- Set `EX_ENABLE_EXTENSION_POINT_GENERATION = YES` on the host (and extension), Debug + Release.
- Rebuild and confirm `ExtensionPointExtractor` ran and `…app/Contents/Extensions/<host>.appexpt` exists and contains your identifier.

## `LSRegisterURL … OSStatus -10819` — LaunchServices warning

**Symptom:** Logged during the "load from disk" registration step.

**Cause:** LaunchServices could not fully register the candidate bundle URL.

**Fix:** **Not fatal.** Log it and continue — rely on `AppExtensionPoint.Monitor` discovery afterward. Make registration best-effort; never abort the flow on this.

## "Failed to get extension process and XPC endpoints" / "Host session request returned nil" / "Invalidated by remote connection"

**Symptom:** `Monitor found 1 identity(s)` (discovery works), but `EXHostViewController` cannot activate the extension process.

**Cause (in this repo):** The extension entry point conformed to a **custom wrapper protocol** around `AppExtension` instead of conforming directly.

**Fix:** Use **direct `AppExtension` conformance** and a **direct `AppExtensionSceneConfiguration`** in the extension's `@main` entry point. Import `ExtensionKit` for `AppExtensionSceneConfiguration`.

## "loaded but cannot send message"

**Symptom:** Extension is discovered/embedded but the host's messages go nowhere; remote proxy is `nil`.

**Cause:** Activation/XPC did not complete even though discovery did.

**Fix:** See `communication.md` §5. The host can only send after `makeXPCConnection()` succeeds and `remoteExtension` is non-nil. Verify `@objc`/`NSObjectProtocol` protocols in shared `core`, matching `sceneID`, direct conformance, and that the host was relaunched.

## `ViewBridge … Code=18`

**Symptom:** Logged when the embedded remote view tears down.

**Cause:** The remote view deactivated.

**Fix:** Treat as **secondary/benign** unless it's paired with an activation/XPC failure. On its own it does not indicate the messaging path is broken.

## Stale metadata after rebuild

**Symptom:** Fixes don't take effect; old errors persist after a successful build.

**Cause:** A still-running host process keeps the old `.appexpt` / extension code.

**Fix:** **Quit and relaunch** the rebuilt host after any change to extension metadata or the entry point. The previously running process will not pick up new `.appexpt` metadata.

## Signing

- Do **not** build the discoverable artifact with `CODE_SIGNING_ALLOWED=NO`. LaunchServices / ExtensionKit must discover and activate a **signed** provider app.
- Build the **host scheme** with signing enabled, then stage both `.app` and `.appex`.

## Quick verification sequence

1. `make extension` (host scheme builds; `ExtensionPointExtractor` runs).
2. Confirm `…app/Contents/Extensions/<host>.appexpt` exists and lists your identifier.
3. `make test` (`swift test --package-path core`).
4. **Quit and relaunch** the staged host app.
5. Load/select the extension → expect `Monitor found 1 identity(s)`.
6. Embed → expect activation → `makeXPCConnection()` succeeds → bidirectional messages flow.
