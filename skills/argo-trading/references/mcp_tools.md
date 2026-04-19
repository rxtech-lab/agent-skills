# ArgoTradingSwift MCP tools — full reference

All tools require a `.rxtrading` document to be open. The server targets the frontmost document window. Default endpoint: `http://127.0.0.1:33321`.

| Tool | Inputs | Returns |
|------|--------|---------|
| `load_strategy` | `strategy_path` (absolute `.wasm` path) | `{status, destination}` or `{isError}` |
| `list_schemas` | `limit` (int), `query?` (string) | `{schemas: [{id, name, created_at}], total}` |
| `read_schema` | `schema_id` (UUID) | `{id, name, strategy_path, backtest_config, live_trading_config, strategy_config}` |
| `update_schema` | `schema_id`, `backtest_config?`, `live_trading_config?`, `strategy_config?` | `{status, schema_id}` |
| `list_data` | — | `{datasets: [{id, name, ticker, start, end, timespan}]}` |
| `select_schema` | `schema_id` (UUID) | `{status, schema_id}` |
| `select_data` | `data_id` (filename) | `{status, data_id}` |
| `run_backtest` | — | `{status, result_path}` (blocking, up to 5 min) |
| `get_config` | — | `{selected_schema, selected_dataset}` (either may be null) |

## Notes

- `load_strategy` overwrites any previously-loaded file with the same name — the strategy name is the identity key.
- `run_backtest` is blocking. Do not retry if it seems slow; it can take up to 5 minutes.
- `get_config` returning null for either field means `run_backtest` will fail — resolve with `select_schema` / `select_data` first.
- `update_schema` accepts partial updates; omit fields to leave them unchanged.

## Raw HTTP transport (diagnostics)

Streamable HTTP JSON-RPC 2.0. Prefer the MCP tools; only fall back to raw HTTP for server-side debugging.

```
POST /
Content-Type: application/json
Accept: application/json
```
