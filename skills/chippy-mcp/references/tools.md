# Chippy MCP tools — full reference

Server name `chippy`. Endpoint `http://127.0.0.1:<port>/mcp` (default port `47823`): Streamable HTTP on the Mac's loopback interface, bearer-token auth. Every tool runs as the account signed in to the Chippy Mac app.

## `add_summary`

Saves a summary written by the agent (`POST /api/v1/summaries/import`). Nothing is re-summarised.

| Argument | Type | Required | Notes |
|----------|------|----------|-------|
| `title` | string | ✓ | ≤ 200 chars |
| `summary` | string | ✓ | ≤ 1200 chars |
| `text` | string | ✓ | Raw source text, ≤ 200,000 chars; kept as the chip's source document |
| `keyPoints` | string[] | | ≤ 5, each ≤ 300 chars; shown as "Key points" |
| `tags` | string[] | | ≤ 12; lowercased and de-duplicated by the server. A comma-separated string is accepted too |
| `keywords` | string[] | | ≤ 10 |
| `category` | enum | | `Technology`, `Science`, `Business`, `Finance`, `Politics`, `World`, `Health`, `Sports`, `Entertainment`, `Culture`, `Education`, `Lifestyle`, `Travel`, `Food`, `Opinion`, `Research`, `Other` (default) |
| `language` | string | | BCP-47 code of the title and summary; default `en` |
| `sourceUrl` | string | | http(s) URL; sets the source label (web / x / facebook / youtube / github) |
| `sourceTitle` | string | | ≤ 1000 chars |
| `siteName` | string | | ≤ 300 chars |
| `visibility` | `public` \| `private` | | default `public` |
| `ttlDays` | 1 \| 3 \| 7 \| 30 \| 90 \| 365 \| `"never"` | | lifetime of the public link; default: server default |
| `allowDuplicate` | boolean | | default `false`; `true` skips the duplicate check |

**Success:** `{ "summary": SummaryItem }`, plus a text line with the title and share link.

**Errors** (`isError: true`, text message):
- Duplicate: *"Not added: this chip is already in the library as "…" (https://…). Reason: … Call add_summary again with allowDuplicate: true to save it anyway."*
- Validation: *"Invalid keyPoints: at most 5 key points, got 7"*, *"Missing required argument: text"*, or a server message such as `VALIDATION_ERROR`.
- Allowance used up: the server's `SUMMARY_ALLOWANCE_EXHAUSTED` message. The user tops up in the app.
- Signed out: *"Chippy is not signed in. Open the Chippy app on this Mac and sign in, then try again."*

Takes up to about 3 minutes (duplicate check + cover design).

## `search_summaries`

Natural-language search, most relevant first (`GET /api/v1/summaries?q=…`).

| Argument | Type | Required | Notes |
|----------|------|----------|-------|
| `query` | string | ✓ | ≤ 200 chars |
| `source` | `web` \| `x` \| `facebook` \| `youtube` \| `github` \| `pdf` \| `text` | | |
| `category` | enum | | as above |
| `tag` | string | | exact tag |
| `visibility` | `public` \| `private` | | |
| `scope` | `all` \| `mine` \| `viewed` | | default `all` |
| `limit` | integer 1–50 | | default 10 |
| `cursor` | string | | `nextCursor` from the previous call |

## `list_summaries`

The library newest first (`GET /api/v1/summaries`). Same filters as search, without `query`. `limit` is 1–200 (default 50). The tool follows the API's 50-item pages internally.

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
