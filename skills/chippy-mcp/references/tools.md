# Chippy MCP tools — full reference

Server name `chippy`. Endpoint `https://summary.rxlab.app/api/mcp`: Streamable HTTP (stateless, JSON responses), authenticated with a personal API key (`Authorization: Bearer chippy_…`). Every tool runs as the account that owns the key, and counts as one tool call in that key's usage.

## `add_summary`

Saves a summary written by the agent (`POST /api/v1/summaries/import`). Nothing is re-summarised. **Free:** it doesn't use the user's summary allowance or points.

| Argument | Type | Required | Notes |
|----------|------|----------|-------|
| `title` | string | ✓ | ≤ 200 chars |
| `summary` | string | ✓ | ≤ 1200 chars |
| `text` | string | ✓ | Raw source text, ≤ 200,000 chars; kept as the chip's source document |
| `keyPoints` | string[] | | ≤ 5, each ≤ 300 chars; shown as "Key points" |
| `tags` | string[] | | ≤ 12; lowercased and de-duplicated by the server. An array of strings |
| `keywords` | string[] | | ≤ 10 |
| `category` | enum | | `Technology`, `Science`, `Business`, `Finance`, `Politics`, `World`, `Health`, `Sports`, `Entertainment`, `Culture`, `Education`, `Lifestyle`, `Travel`, `Food`, `Opinion`, `Research`, `Other` (default) |
| `language` | string | | BCP-47 code of the title and summary. Only a hint: the server detects the chip's and the source's language itself |
| `sourceUrl` | string | | http(s) URL; sets the source label (web / x / facebook / youtube / github) |
| `sourceTitle` | string | | ≤ 1000 chars |
| `siteName` | string | | ≤ 300 chars |
| `visibility` | `public` \| `private` | | default `public` |
| `ttlDays` | 1 \| 3 \| 7 \| 30 \| 90 \| 365 \| `"never"` | | lifetime of the public link; default: server default |
| `allowDuplicate` | boolean | | default `false`; `true` skips the duplicate check |

**Success:** `{ "summary": SummaryItem }`, plus a text line with the title and share link.

**Errors** (`isError: true`, text message):
- Duplicate: *"Not added: this chip is already in the library as "…" (https://…). Reason: … Call add_summary again with allowDuplicate: true to save it anyway."*
- Validation: the argument and the limit it broke, e.g. *"Invalid keyPoints: Too big: expected array to have <=5 items"*. A missing or mistyped required argument (`title`, `summary`, `text`) is reported the same way, as a tool error.
- Bad or revoked key: HTTP `401` (`INVALID_API_KEY`) before any tool runs. The user creates a new key in Settings → MCP Server.

Takes up to about 3 minutes (duplicate check + cover design).

## `update_summary`

Edits one of the user's own chips, with the same validation as the app's edit. **Free.**

| Argument | Type | Required | Notes |
|----------|------|----------|-------|
| `summaryId` | string | ✓ | The chip's `id` from search or list |
| `title` | string | | ≤ 200 chars |
| `summary` | string | | ≤ 1200 chars |
| `keyPoints` | string[] | | ≤ 5, each ≤ 300 chars; **replaces** the list |
| `tags` | string[] | | ≤ 12; **replaces** the list; lowercased by the server |
| `keywords` | string[] | | ≤ 10 |
| `category` | enum | | as above |
| `visibility` | `public` \| `private` | | |
| `ttlDays` | 1 \| 3 \| 7 \| 30 \| 90 \| 365 \| `"never"` | | lifetime of the public link, counted from now |

Pass at least one field; the others stay as they are. Text is stored as written, so write it in the chip's `language`. Editing the summary or key points drops its translations, and they are made again on the next read. The cover isn't redesigned. Each text edit saves a version.

**Success:** `{ "summary": SummaryItem }`, plus a text line with the title, visibility and share link.

**Errors:** *"Nothing to change: pass at least one field."*; validation errors as for `add_summary`; and a pointer to the right tool when the id is a trip (`update_trip`), a paper (`update_paper`) or a Mini App (`update_mini_app`).

## `search_summaries`

Natural-language search, most relevant first (`GET /api/v1/summaries?q=…`).

| Argument | Type | Required | Notes |
|----------|------|----------|-------|
| `query` | string | ✓ | ≤ 200 chars |
| `source` | `web` \| `x` \| `facebook` \| `youtube` \| `github` \| `pdf` \| `text` | | |
| `category` | enum | | as above |
| `tag` | string | | exact tag |
| `visibility` | `public` \| `private` | | |
| `kind` | `summary` \| `trip` \| `paper` \| `mini_app` \| `podcast` | | only items of this kind; open trips, papers and Mini Apps with `get_trip`, `get_paper`, `get_mini_app` |
| `scope` | `all` \| `mine` \| `viewed` \| `liked` | | default `all`; `liked` = chips the user starred, most recently starred first |
| `limit` | integer 1–50 | | default 10 |
| `cursor` | string | | `nextCursor` from the previous call |

## `list_summaries`

The library newest first (`GET /api/v1/summaries`). Same filters as search, without `query`. `limit` is 1–10 (default 10); follow `nextCursor` for more.

## `list_editors_picks`

The user's current Editor's Picks (summary and podcast chips, private ones included), grouped by the day each chip was created.

| Argument | Type | Required | Notes |
|----------|------|----------|-------|
| `date` | `today` \| `yesterday` \| `YYYY-MM-DD` | | default `today` |
| `timeZone` | string | | IANA zone; default the user's most recent device time zone, then UTC |
| `limit` | integer 1–50 | | default 20 |
| `cursor` | string | | `nextCursor` from a call with the same date and time zone |

**Success:** `{ "date", "timeZone", "dateBasis": "createdAt", "decision": "current saved editorial picks", "results": [ … each chip with its editorial "score" ], "nextCursor": "…" | null }`. These are the picks as saved now, not past ranking snapshots.

## `list_versions` / `get_version` / `restore_version`

Version history of the user's own chips, trips and papers. All three are free.

| Tool | Arguments | Returns |
|------|-----------|---------|
| `list_versions` | `id`, optional `cursor` | Versions newest first (20 per page): number, who saved it (owner, agent, chat, source, restore), when, and the title then. The latest 100 are kept |
| `get_version` | `id`, `version` | That version's content: a chip's title, summary, highlights (key points), category, tags and keywords |
| `restore_version` | `id`, `version` | Saves the old content as a new version (so it can be undone) and returns `{ version, summary }`. Sharing, language and the cover don't change. Call it only when the user asks |

Each edit of a chip's text is a version. Sharing and language changes aren't.

## Result shape (search and list)

```json
{
  "count": 2,
  "items": [SummaryItem, …],
  "nextCursor": "…" | null
}
```

`SummaryItem`:

```json
{
  "id": "5f0c7a0e-…",
  "title": "Monarch migration",
  "summary": "Monarch butterflies fly thousands of kilometres south every autumn.",
  "keyPoints": ["They travel up to 4,000 km", "No single butterfly makes the round trip"],
  "category": "Science",
  "tags": ["butterflies", "migration"],
  "source": "web",
  "sourceUrl": "https://example.com/monarchs",
  "sourceTitle": "The great monarch migration",
  "siteName": "Example",
  "shareUrl": "https://summary.rxlab.app/s/a1B2c3D4e5",
  "visibility": "public",
  "language": "en",
  "isOwner": true,
  "hasSourceText": true,
  "createdAt": "2026-10-01T00:00:00Z",
  "viewedAt": null
}
```

`isOwner: false` marks someone else's public chip the user opened. `viewedAt` is when they opened it.
