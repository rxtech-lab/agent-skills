# Version Bumping

Two distinct version fields ship in every Android build. They are owned by different systems so they never collide, and **neither is committed to the repo**.

| Field | Android name | Source | Owner |
|-------|--------------|--------|-------|
| `expo.version` | `versionName` (human-facing, e.g. `1.2.3`) | Git release tag | rewritten into `app.json` at build time |
| `versionCode` | monotonic integer (e.g. `42`) | EAS server-side counter | EAS (`appVersionSource: remote` + `autoIncrement`) |

## versionName — from the release tag

The release tag drives the user-facing version. Before building, the workflow rewrites `app.json`:

```bash
VERSION="${GITHUB_REF_NAME#v}"   # v1.2.3 -> 1.2.3
cat <<< "$(jq --arg v "$VERSION" '.expo.version = $v' app.json)" > app.json
```

Notes:

- `${GITHUB_REF_NAME#v}` strips a leading `v` so the tag `v1.2.3` yields `1.2.3`.
- `cat <<< "$(jq ... app.json)" > app.json` is the safe in-place rewrite — `jq` cannot read and write the same file in one pipe, so its output is captured first via a here-string, then written back.
- This runs **only on `release` events**. On a plain `push` (smoke build) the tag is absent and the existing `app.json` version is used.
- The change is made on the CI runner only and never committed — the repo's `app.json` version stays at whatever placeholder you keep there.

Helper: `scripts/set-version.sh [version]` does the same with validation; it falls back to `GITHUB_REF_NAME` when no argument is passed.

## versionCode — owned by EAS

Set once in `eas.json`:

```json
{
  "cli": { "appVersionSource": "remote" },
  "build": { "production": { "android": { "autoIncrement": true } } }
}
```

- `appVersionSource: "remote"` tells EAS to track the last-used `versionCode` on its servers instead of reading it from `app.json`.
- `autoIncrement: true` bumps that counter on every production build.

Google Play requires each upload's `versionCode` to be strictly greater than the previous one on the track. Letting EAS own it removes hand-bumping, merge conflicts on a committed integer, and "duplicate versionCode" upload rejections. See [eas-config.md](eas-config.md).

## Why split ownership

- The **tag** is the single source of truth for the marketing version a tester sees.
- The **versionCode** is an implementation detail Play needs to be monotonic — humans should never have to pick it.

Result: cut a release tagged `v1.2.3`, and the build ships `versionName 1.2.3` with the next available EAS-assigned `versionCode`, with nothing version-related committed.
