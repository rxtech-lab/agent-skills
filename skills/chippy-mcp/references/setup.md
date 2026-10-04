# Connecting an agent to Chippy

## Create an API key in the app

1. Open Chippy on iPhone, iPad or Mac and sign in.
2. **Settings → MCP Server**: under *Integrations* on iOS, under *General* (**Configure…**) on macOS.
3. Press **+** (**New API Key**), name the key after the agent or device that will use it (for example "Claude Code on my laptop"), and press **Create**.
4. The key (`chippy_…`) is shown **once**. Copy it, or pick the agent under **Connect an Agent** and press **Copy Configuration**. The configuration already contains the URL and the key.

The server is `https://summary.rxlab.app/api/mcp` (Streamable HTTP, stateless, JSON responses). It is always on, from any machine. Every request needs `Authorization: Bearer <api key>`, and the agent acts as the account that created the key.

The MCP Server sheet lists the account's keys with their usage: tool calls, summaries added, created and last used. From there a key can be **renamed** or **revoked**. Revoking takes effect on the agent's next request. Only a hash of each key is stored, so a lost key can't be shown again; revoke it and create a new one. An account can have up to 25 keys.

## Claude Code

```sh
claude mcp add --transport http chippy https://summary.rxlab.app/api/mcp \
  --header "Authorization: Bearer <api key>"
```

Add `--scope user` to make it available in every project. Check it with `claude mcp list`. `chippy` should show as connected.

## Cursor, VS Code, project `.mcp.json`

```json
{
  "mcpServers": {
    "chippy": {
      "type": "http",
      "url": "https://summary.rxlab.app/api/mcp",
      "headers": { "Authorization": "Bearer <api key>" }
    }
  }
}
```

Keep the key out of committed files. Prefer user-level configuration, or an environment variable if the agent supports one in headers.

## Claude Desktop

Claude Desktop's config file only starts stdio servers. Bridge to the HTTP endpoint with `mcp-remote` (needs Node.js). In **Settings → Developer → Edit Config**:

```json
{
  "mcpServers": {
    "chippy": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://summary.rxlab.app/api/mcp", "--header", "Authorization: Bearer <api key>"]
    }
  }
}
```

Restart Claude Desktop afterwards.

## Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| `401` `MISSING_API_KEY` | The `Authorization: Bearer …` header isn't sent. Check the agent's configuration |
| `401` `INVALID_API_KEY` ("invalid or has been revoked") | The key was revoked, mistyped, or belongs to a deleted account. Create a new key in Settings → MCP Server |
| `405` on `GET` | Expected: the server is stateless and has no server-to-client stream. Clients fall back to plain `POST` |
| A tool says the allowance is used up | The user's free summaries for today are used and they have no points. They top up in Settings → Summaries & Points |
| `add_summary` is slow | Normal. The duplicate check and cover design take up to ~3 minutes |

Manual check (expect `401` without the header, and a JSON-RPC `result` with it):

```sh
curl -i https://summary.rxlab.app/api/mcp \
  -H "Authorization: Bearer <api key>" -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl","version":"1"}}}'
```
