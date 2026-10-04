# Connecting an agent to Chippy

## In the app

1. Open Chippy on the Mac and sign in.
2. **Settings → Integrations → MCP Server → Configure…**
3. Turn on **Enable MCP Server**. The status reads *Running on port 47823*. The server starts automatically whenever Chippy launches.
4. Under **Connect an Agent**, pick the agent and press **Copy**. The configuration already contains the URL and the access token.

The server listens only on `127.0.0.1` and only while Chippy is open. Every request needs `Authorization: Bearer <token>`. **Regenerate Token…** invalidates every configured agent.

## Claude Code

```sh
claude mcp add --transport http chippy http://127.0.0.1:47823/mcp \
  --header "Authorization: Bearer <token>"
```

Add `--scope user` to make it available in every project. Check it with `claude mcp list`. `chippy` should show as connected.

## Cursor, VS Code, project `.mcp.json`

```json
{
  "mcpServers": {
    "chippy": {
      "type": "http",
      "url": "http://127.0.0.1:47823/mcp",
      "headers": { "Authorization": "Bearer <token>" }
    }
  }
}
```

## Claude Desktop

Claude Desktop's config file only starts stdio servers. Bridge to the HTTP endpoint with `mcp-remote` (needs Node.js). In **Settings → Developer → Edit Config**:

```json
{
  "mcpServers": {
    "chippy": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "http://127.0.0.1:47823/mcp", "--header", "Authorization: Bearer <token>"]
    }
  }
}
```

Restart Claude Desktop afterwards.

## Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| Connection refused | Chippy isn't open, or the server is off. Open Chippy and check the status in the MCP Server sheet |
| `401` / "Missing or invalid access token" | The token was regenerated or mistyped. Copy the configuration again |
| Status shows "Couldn't start", port in use | Another process has the port. Pick another port in the sheet and update the agent's URL |
| `404` "unknown MCP-Session-Id" | Chippy restarted, so its sessions were dropped. Most clients reconnect automatically; otherwise restart the agent |
| Every tool says "not signed in" | Sign in to the Chippy app |
| `add_summary` is slow | Normal. The duplicate check and cover design take up to ~3 minutes |

Manual check (expect `401` without the header, and an SSE `result` with the header):

```sh
curl -i http://127.0.0.1:47823/mcp \
  -H "Authorization: Bearer <token>" -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl","version":"1"}}}'
```
