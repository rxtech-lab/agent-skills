#!/usr/bin/env python3
"""Summarize an ArgoTradingSwift backtest result folder.

Usage:
    python3 analyze_backtest.py <result_path>

Prints stats.yaml, describes per-trade pnl, and compares against buy-and-hold
when the comparison is available in stats.yaml.

Requires: pyyaml, duckdb, pandas.
"""

from __future__ import annotations

import sys
from pathlib import Path

import duckdb
import yaml


def _find_stat(stats: dict, *keys: str):
    """Return the first non-None value among the given keys (case-insensitive)."""
    lower = {k.lower(): v for k, v in stats.items()}
    for key in keys:
        v = lower.get(key.lower())
        if v is not None:
            return v
    return None


def main(run: str) -> int:
    run_path = Path(run).expanduser().resolve()
    stats_path = run_path / "stats.yaml"
    if not stats_path.exists():
        print(f"ERROR: {stats_path} not found", file=sys.stderr)
        return 1

    with stats_path.open() as f:
        stats = yaml.safe_load(f) or {}

    print("=== stats.yaml ===")
    print(yaml.safe_dump(stats, sort_keys=False).rstrip())

    parquets = sorted(run_path.glob("*.parquet"))
    if not parquets:
        print("\nNo per-trade parquet found in run folder.", file=sys.stderr)
        return 0

    con = duckdb.connect()
    pattern = str(run_path / "*.parquet").replace("'", "''")
    trades = con.execute(f"SELECT * FROM '{pattern}'").df()

    print(f"\n=== trades ({len(trades)} rows from {len(parquets)} parquet file(s)) ===")
    print(trades.head().to_string())

    if "pnl" in trades.columns:
        print("\n=== pnl.describe() ===")
        print(trades["pnl"].describe().to_string())
        total_pnl = float(trades["pnl"].sum())
        wins = int((trades["pnl"] > 0).sum())
        losses = int((trades["pnl"] < 0).sum())
        print(f"\ntotal_pnl={total_pnl:.4f}  wins={wins}  losses={losses}")
    else:
        print("\n(no 'pnl' column — inspect trade columns manually)")
        print("columns:", list(trades.columns))

    strat = _find_stat(stats, "total_return", "strategy_return", "pnl", "return")
    bh = _find_stat(stats, "buy_and_hold", "buy_and_hold_return", "benchmark_return", "bh_return")
    if strat is not None and bh is not None:
        try:
            diff = float(strat) - float(bh)
            verdict = "BEATS" if diff > 0 else "LOSES TO"
            print(f"\n=== verdict vs buy-and-hold ===")
            print(f"strategy={strat}  buy_and_hold={bh}  diff={diff:+.4f}  → {verdict} buy-and-hold")
        except (TypeError, ValueError):
            pass
    else:
        print("\n(could not locate strategy vs buy-and-hold fields in stats.yaml — "
              "inspect the printed stats above manually)")

    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: analyze_backtest.py <result_path>", file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
