---
name: argo-trading
description: Iterate on algorithmic trading strategies in ArgoTradingSwift (`.rxtrading` documents) via the embedded MCP server. Use when the user wants to write, build, backtest, or improve Go-based trading strategies that compile to WASM, load a `.wasm` strategy into the app, run a backtest against a schema/dataset, or analyze backtest results (stats.yaml + per-trade parquet). Triggers include phrases like "write a trading strategy", "backtest this strategy", "beat buy-and-hold", "load_strategy", "run_backtest", and any mention of argo-trading, ArgoTradingSwift, or `.rxtrading` files.
---

# ArgoTrading Strategy Iteration

## Overview

ArgoTradingSwift runs Go strategies compiled to WASM against historical datasets. Iterate on a strategy by editing Go code, building it, loading it through the MCP server, and analyzing the backtest results to beat buy-and-hold.

## Prerequisites

Before calling any tool, confirm:

1. A `.rxtrading` document is open in ArgoTradingSwift (the MCP server always targets the frontmost document window — no document means every tool errors).
2. The MCP server is reachable. Default endpoint: `http://127.0.0.1:33321` (probes upward if the port is taken). Stop/change it from **Settings → MCP**.
3. `get_config` returns a selected schema and dataset before `run_backtest` — otherwise select them first with `select_schema` / `select_data`.

## Strategy iteration workflow

Follow these steps in order. Do not skip result analysis; without the numbers there is no way to know whether an edit helped.

### 1. Write or edit the Go strategy

Framework API reference: https://rxtech-lab.github.io/argo-trading/

**Keep the strategy name stable across edits.** Renaming mid-experiment breaks result comparisons. Pick a name on the first version and reuse it.

### 2. Build the WASM artifact

From the strategy repo:

```bash
make build
```

This produces a `.wasm` file. Note the absolute path — `load_strategy` requires it.

### 3. Back up a profitable `.wasm` before rewriting

If the current strategy is green and beats buy-and-hold, copy the `.wasm` out of the project strategy folder before making a risky edit. Regressions happen; the old binary is the only way back.

### 4. Load the strategy

Call `load_strategy` with the absolute `.wasm` path. It overwrites any previous file with the same name.

### 5. Select schema and dataset

- `list_schemas` / `list_data` to discover IDs if unknown.
- `select_schema` with a schema UUID.
- `select_data` with a dataset filename.
- Optionally `read_schema` + `update_schema` to tune `backtest_config`, `live_trading_config`, or `strategy_config`.
- Verify with `get_config`.

### 6. Run the backtest

Call `run_backtest`. It blocks for up to 5 minutes and returns `{status, result_path}`.

### 7. Analyze results (required)

**Agents cannot see the chart — do not eyeball it.** Always analyze with a Python script that reads `stats.yaml` and the per-trade parquet.

Use the bundled analyzer:

```bash
python3 scripts/analyze_backtest.py <result_path>
```

It prints `stats.yaml`, summarizes `pnl`, and reports whether the strategy beat buy-and-hold. For ad-hoc exploration, load the parquet with DuckDB — see `references/analysis.md`.

### 8. Judge against buy-and-hold

The goal is to **beat buy-and-hold on the chosen dataset**, not just to be green. `stats.yaml` reports both numbers. If the strategy underperforms buy-and-hold, iterate (return to step 1) — don't ship.

## MCP tools

Quick cheat-sheet. Full input/output schemas in `references/mcp_tools.md`.

| Tool | Purpose |
|---|---|
| `load_strategy` | Import a `.wasm` file (absolute path). |
| `list_schemas` / `read_schema` / `update_schema` | Discover and edit schema configs. |
| `list_data` | List available datasets. |
| `select_schema` / `select_data` | Choose what the next backtest runs with. |
| `get_config` | Read currently selected schema + dataset. |
| `run_backtest` | Blocking run; returns `result_path`. |

Transport is Streamable HTTP JSON-RPC 2.0. For raw HTTP calls (diagnostics only — prefer the MCP tools): `POST /` with `Content-Type: application/json` and `Accept: application/json` to the server endpoint.

## Iteration rules (do not violate)

- Keep the strategy **name** stable across edits.
- **Back up** profitable `.wasm` files before rewriting.
- **Always analyze with Python**, never by eyeballing the chart.
- The bar is **beat buy-and-hold**, not just positive PnL.

## References

- `references/mcp_tools.md` — full MCP tool input/output schemas.
- `references/analysis.md` — DuckDB + yaml patterns for deeper trade-level analysis.
- `scripts/analyze_backtest.py` — run this on every `result_path` before concluding.
