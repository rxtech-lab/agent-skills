---
name: chippy-mcp
description: Save, edit, search and list summaries in the user's Chippy library (summary cards, "chips") through Chippy's hosted MCP server (summary.rxlab.app/api/mcp), authenticated with a personal API key. Use when the user wants to save or add a summary of an article, video, thread, document or notes to Chippy; find something they summarised before ("what did I save about…", "search my chips for…"); browse or list their summaries by source (web, X, Facebook, YouTube, GitHub, PDF, text), category, tag, visibility or kind; fix or re-share a chip they own; read today's Editor's Picks; or view and restore a chip's earlier versions. Triggers include Chippy, chips, summary chip, summary.rxlab.app, add_summary, update_summary, search_summaries, list_summaries, list_editors_picks, and requests to "save this to my library". It replaces the retired `chippy` CLI and the old local MCP server in the Mac app.
---

# Chippy MCP

## Overview

Chippy turns articles, posts, videos and documents into summary cards ("chips"). Chippy's server hosts an MCP server at `https://summary.rxlab.app/api/mcp`. Through it, an agent can add chips to the user's library and read the library back, acting as the account that owns the API key. It works from any machine, and the Chippy app doesn't need to be open.

| Tool | Use it to |
|------|-----------|
| `add_summary` | Save a summary **you wrote** with its key points, tags and the raw source text |
| `search_summaries` | Find chips by meaning with a natural-language query, optionally from one source |
| `list_summaries` | List chips newest first by source, category, tag, visibility, kind or scope |
| `update_summary` | Edit the title, summary, key points, tags, keywords, category, visibility or link lifetime of a chip the user owns |
| `list_editors_picks` | Read the user's Editor's Picks for a day (`today`, `yesterday` or `YYYY-MM-DD`) |
| `list_versions` / `get_version` / `restore_version` | Read a chip's edit history and bring an earlier version back |

All of these are **free**: adding, editing and restoring chips don't use the user's daily summary allowance or points. The same server also has tools for trips, papers, Mini Apps and podcasts (see the server's instructions); a few of those, such as `create_podcast` and `add_to_trip_from_source`, cost points.

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
   - `language`: BCP-47 code of the language **you wrote** the title and summary in (`en`, `zh-Hant`, `ja`…). It's only a hint; the server works out the chip's and the source's language itself. Write in the user's language unless they ask otherwise.
   - `sourceUrl`, `sourceTitle`, `siteName`: set them whenever the text came from the web. `sourceUrl` also drives the source label (X, YouTube, GitHub…).
3. **Respect the user's sharing choice.** The default `visibility` is `public` (anyone with the link can open it). Use `private` for personal notes or when the user asks. `ttlDays` (1, 3, 7, 30, 90, 365 or `"never"`) sets how long the public link stays alive.
4. **Call `add_summary`.** It can take up to ~3 minutes, because the server checks for duplicates and designs the cover. Don't retry while it's running.
5. **Report the share link** (`summary.shareUrl`) to the user.

**Duplicates.** If the library already has this chip (same source, title or content), the tool returns an error naming the existing chip and its link. Tell the user and share that link. Only call again with `allowDuplicate: true` if the user wants a second copy.

**Cost.** `add_summary` is free. It doesn't use the user's summary allowance or points. It still writes to the user's library, though. Don't add test chips or add the same source twice, and confirm with the user before a run that would add many chips.

## Editing a chip (`update_summary`)

- Get the chip's `id` from `search_summaries` or `list_summaries`. Only chips the user owns (`isOwner: true`) can be edited. Trips, papers and Mini Apps have their own tools (`update_trip`, `update_paper`, `update_mini_app`).
- Pass only the fields to change. Others stay as they are. `keyPoints` and `tags` **replace** the whole list, so send the full new list.
- Write in the chip's `language`, because the text is stored as written. Editing the summary or key points drops its translations, and they are made again on the next read. The cover isn't redesigned.
- `visibility` and `ttlDays` (counted from now) change how the chip is shared. Change them only when the user asks.
- Every text edit saves a version. If an edit went wrong, `list_versions` → `get_version` → `restore_version` brings the old text back. A restore is saved as a new version too, so it can be undone. Restore only when the user asks.

## Card artwork and layouts

For requests to design or improve a summary/briefing card's cover, use [Chippy Card Design](../chippy-card-design/SKILL.md). It provides varied compositions and guidance for crops and title placement. The current `add_summary` schema has no cover-layout or image-prompt field; the server chooses the cover. Do not insert design directions into summary content or raw source text, and do not claim that loading the design skill changes MCP-generated covers.

## Podcast videos

To author or redesign the animated video of a Chippy podcast episode (`get_podcast_project`, `render_podcast_frame`, `submit_podcast_video`…), use [Chippy Podcast Video](../chippy-podcast-video/SKILL.md). It builds on this skill's connection setup.

## Finding chips

- **By topic or question** → `search_summaries` with a natural-language `query` (≤ 200 chars) such as "battery recycling startups". It matches by meaning, so describe the idea; you don't need the exact title words. Add `source` when the user names a platform ("the YouTube video about…" → `source: "youtube"`).
- **By filter only** ("my latest GitHub chips", "everything tagged rust", "my private chips") → `list_summaries`. It returns up to 10 per call, newest first; follow `nextCursor` for more.
- **Paging:** both tools return `nextCursor`. Pass it back as `cursor` with the same filters. `null` means there is nothing more.
- **Scope:** `all` (default) is the user's own chips plus others' public chips they opened. Use `mine` for "chips I made", `viewed` for "chips people shared with me" and `liked` for "chips I starred" (most recently starred first).
- **Kind:** the library also holds trips, papers, Mini Apps and podcasts. Pass `kind: "summary"` to get only summary cards, or another kind to find those items. Open them with `get_trip`, `get_paper` or `get_mini_app`.
- **Editor's Picks** ("today's picks", "what did the editor pick yesterday") → `list_editors_picks` with `date` (`today` by default) and an optional IANA `timeZone`. It shows the user's current picks grouped by the day each chip was created; it doesn't keep past rankings. Follow `nextCursor` with the same date and time zone.
- **Citing:** each item has `title`, `summary`, `keyPoints`, `shareUrl` and `sourceUrl`. Quote from these and link `shareUrl`. Don't invent content beyond what the chip contains.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Passing the article URL alone and expecting the server to summarise it | Read the source yourself; send `title`, `summary`, `keyPoints` and the raw `text` |
| Putting your summary in `text` | `text` is the **raw source**; your writing goes in `summary` / `keyPoints` |
| Using `list_summaries` to find a topic | Use `search_summaries`; list has no query |
| Sending only the new key point to `update_summary` | `keyPoints` and `tags` replace the list; send the full list |
| Telling the user that adding a chip uses their allowance or points | `add_summary`, `update_summary` and `restore_version` are free |
| Retrying after a duplicate error | Share the existing chip's link; use `allowDuplicate` only if the user asks |
| Retrying after `401` / "invalid or has been revoked" | The key was revoked or mistyped. Ask the user to create a new key in Settings → MCP Server |
| Invented category such as "Gardening" | Use one of the 17 categories, or `Other` |
