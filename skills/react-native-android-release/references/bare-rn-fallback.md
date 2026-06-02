# Bare React Native (Gradle) Fallback

The **primary path of this skill is Expo managed workflow + EAS**. Use this fallback only when the project is **bare React Native** — i.e. it commits its own `android/` directory with `build.gradle`, `signingConfigs`, and a checked-in keystore reference, and does not (or cannot) route builds through EAS.

> Prefer EAS where possible: it manages the keystore, the Android project, and the Play upload for you with just `EXPO_TOKEN` + a service account. Reach for Gradle/Fastlane only when an existing bare project already owns its `android/`.

## When you are on this path

Signs you are bare, not managed:

- A committed `android/` directory with `app/build.gradle`
- A `signingConfigs { release { ... } }` block referencing a `.keystore`/`.jks`
- No reliance on `eas build` for the Android artifact

## Signing: keystore as a base64 secret

Apply the **same credential hygiene** as the service account — never commit the keystore or its passwords:

1. Base64-encode the upload keystore and store it as a secret (e.g. `ANDROID_KEYSTORE_B64`)
2. Store `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` as secrets
3. Decode at runtime in CI:

   ```bash
   echo "$ANDROID_KEYSTORE_B64" | base64 -d > android/app/upload.keystore
   ```

4. Have `signingConfigs.release` read the alias/passwords from `gradle.properties` populated by env, or from `System.getenv(...)` directly

Gitignore: `*.keystore`, `*.jks`, and any `keystore.properties`.

## Build the AAB with Gradle

```bash
cd android
./gradlew bundleRelease    # outputs app/build/outputs/bundle/release/app-release.aab
```

Set the JS bundling and `versionName`/`versionCode` in `android/app/build.gradle` (e.g. read `versionName` from the tag via a Gradle property, and bump `versionCode` from the CI run number or `git rev-list --count HEAD`).

## Publish to the internal track

Two common options instead of EAS Submit:

### Option A — Gradle Play Publisher (Triplet)

Add the [`com.github.triplet.play`](https://github.com/Triple-T/gradle-play-publisher) plugin:

```gradle
plugins { id "com.github.triplet.play" version "<latest>" }

play {
    serviceAccountCredentials = file("google-service-account.json")  // decoded at runtime
    track = "internal"
}
```

```bash
./gradlew publishReleaseBundle
```

### Option B — Fastlane supply

```ruby
# fastlane/Fastfile
lane :internal do
  gradle(task: "bundleRelease")
  upload_to_play_store(
    track: "internal",
    aab: "android/app/build/outputs/bundle/release/app-release.aab",
    json_key: "google-service-account.json"   # decoded at runtime from a base64 secret
  )
end
```

Both still consume the **same** Google Play service account via the base64-secret flow described in [signing-and-credentials.md](signing-and-credentials.md) — only the upload mechanism differs.

## Workflow shape

The GitHub Actions structure is identical to the EAS template — same `on: { release, push }` trigger, same JDK 17 / Node 20 setup, same push-vs-release gating. Swap the two EAS steps for their Gradle/Fastlane equivalents:

| EAS step | Bare RN replacement |
|----------|---------------------|
| `eas build --local --output ./build-android.aab` | `cd android && ./gradlew bundleRelease` |
| `eas submit --profile internal` | `./gradlew publishReleaseBundle` *or* `fastlane internal` |
| EAS-managed keystore (`EXPO_TOKEN`) | decode `ANDROID_KEYSTORE_B64` at runtime + `signingConfigs` |

Keep the version-bump and service-account-decode steps unchanged.
