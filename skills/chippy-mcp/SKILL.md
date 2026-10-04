---
name: chippy-mcp
description: Save, search and list summaries in the user's Chippy library (summary cards, "chips") through Chippy's hosted MCP server (summary.rxlab.app/api/mcp), authenticated with a personal API key. Use when the user wants to save or add a summary of an article, video, thread, document or notes to Chippy; find something they summarised before ("what did I save about…", "search my chips for…"); or browse or list their summaries by source (web, X, Facebook, YouTube, GitHub, PDF, text), category, tag or visibility. Triggers include Chippy, chips, summary chip, summary.rxlab.app, add_summary, search_summaries, list_summaries, and requests to "save this to my library". It replaces the retired `chippy` CLI and the old local MCP server in the Mac app.
---

# Chippy MCP

## Overview

Chippy turns articles, posts, videos and documents into summary cards ("chips"). Chippy's server hosts an MCP server at `https://summary.rxlab.app/api/mcp`. Through it, an agent can add chips to the user's library and read the library back, acting as the account that owns the API key. It works from any machine, and the Chippy app doesn't need to be open.

| Tool | Use it to |
|------|-----------|
| `add_summary` | Save a summary **you wrote** with its key points, tags and the raw source text |
| `search_summaries` | Find chips by meaning with a natural-language query, optionally from one source |
| `list_summaries` | List chips newest first by source, category, tag, visibility or scope |

Full input/output schemas: `references/tools.md`.

## Prerequisites

1. **The user has an API key.** Keys are created in the Chippy app, on iPhone, iPad or Mac: **Settings → MCP Server** (under *Integrations* on iOS, *General* on macOS) → **+ New API Key**. The key (`chippy_…`) is shown **once**, together with ready-made configuration for Claude Code, Claude Desktop and JSON-configured agents. Suggest one key per agent or device, so each can be revoked on its own.
2. **The agent is connected.** If the `chippy` tools aren't available, have the user create a key and add the server. For Claude Code:

   ```sh
   claude mcp add --transport http chippy https://summary.rxlab.app/api/mcp \
     --header "Authorization: Bearer <api key>"
   ```

   Never ask the user to paste the key into the chat if you can avoid it, and never write it into files that get committed.

   Setup details for other agents, and troubleshooting: `references/setup.md`.

## Adding a summary (`add_summary`)

Nothing is re-summarised on the server. **You write** the title, summary and key points, and the server stores them as given. It also designs an illustrated cover and indexes the chip for search.

1. **Read the source in full** (fetch the page, read the file, take the transcript) and keep the raw text. It goes in `text` and becomes the chip's source document.
2. **Write the chip:**
   - `title`: ≤ 200 chars, specific, not clickbait.
   - `summary`: ≤ 1200 chars, 2–4 sentences that stand alone.
   - `keyPoints`: up to 5, each ≤ 300 chars. They show as "Key points". Without them the chip shows none, so include them.
   - `tags`: up to 12 short lowercase topics. `keywords`: up to 10 search terms.
   - `category`: one of Technology, Science, Business, Finance, Politics, World, Health, Sports, Entertainment, Culture, Education, Lifestyle, Travel, Food, Opinion, Research, Other.
   - `language`: BCP-47 code of the language **you wrote** the title and summary in (`en`, `zh-Hant`, `ja`…). Write in the user's language unless they ask otherwise.
   - `sourceUrl`, `sourceTitle`, `siteName`: set them whenever the text came from the web. `sourceUrl` also drives the source label (X, YouTube, GitHub…).
3. **Respect the user's sharing choice.** The default `visibility` is `public` (anyone with the link can open it). Use `private` for personal notes or when the user asks. `ttlDays` (1, 3, 7, 30, 90, 365 or `"never"`) sets how long the public link stays alive.
4. **Call `add_summary`.** It can take up to ~3 minutes, because the server checks for duplicates and designs the cover. Don't retry while it's running.
5. **Report the share link** (`summary.shareUrl`) to the user.

**Duplicates.** If the library already has this chip (same source, title or content), the tool returns an error naming the existing chip and its link. Tell the user and share that link. Only call again with `allowDuplicate: true` if the user wants a second copy.

**Cost.** Each added chip counts as one summary against the user's allowance. Don't add test chips, and don't add the same source twice. When a run would add many chips, confirm with the user first.

## Card artwork and layouts

For requests to design or improve a summary/briefing card's cover, use [Chippy Card Design](../chippy-card-design/SKILL.md). It provides varied compositions and guidance for crops and title placement. The current `add_summary` schema has no cover-layout or image-prompt field; the server chooses the cover. Do not insert design directions into summary content or raw source text, and do not claim that loading the design skill changes MCP-generated covers.

## Finding chips

- **By topic or question** → `search_summaries` with a natural-language `query` (≤ 200 chars) such as "battery recycling startups". It matches by meaning, so describe the idea; you don't need the exact title words. Add `source` when the user names a platform ("the YouTube video about…" → `source: "youtube"`).
- **By filter only** ("my latest GitHub chips", "everything tagged rust", "my private chips") → `list_summaries`. It returns up to 200 per call (default 50), newest first.
- **Paging:** both tools return `nextCursor`. Pass it back as `cursor` with the same filters. `null` means there is nothing more.
- **Scope:** `all` (default) is the user's own chips plus others' public chips they opened. Use `mine` for "chips I made" and `viewed` for "chips people shared with me".
- **Citing:** each item has `title`, `summary`, `keyPoints`, `shareUrl` and `sourceUrl`. Quote from these and link `shareUrl`. Don't invent content beyond what the chip contains.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Passing the article URL alone and expecting the server to summarise it | Read the source yourself; send `title`, `summary`, `keyPoints` and the raw `text` |
| Putting your summary in `text` | `text` is the **raw source**; your writing goes in `summary` / `keyPoints` |
| Using `list_summaries` to find a topic | Use `search_summaries`; list has no query |
| Retrying after a duplicate error | Share the existing chip's link; use `allowDuplicate` only if the user asks |
| Retrying after `401` / "invalid or has been revoked" | The key was revoked or mistyped. Ask the user to create a new key in Settings → MCP Server |
| Invented category such as "Gardening" | Use one of the 17 categories, or `Other` |
