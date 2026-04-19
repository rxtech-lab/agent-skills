# Deeper backtest analysis

The bundled `scripts/analyze_backtest.py` handles the common case. For ad-hoc exploration, load the parquet with DuckDB directly.

## Run folder layout

```
<result_path>/
├── stats.yaml              # summary: PnL, buy-and-hold, win rate, etc.
└── *.parquet               # per-trade rows; exact name varies by dataset
```

## DuckDB + yaml pattern

```python
import duckdb
import yaml

run = "<result_path returned by run_backtest>"

with open(f"{run}/stats.yaml") as f:
    stats = yaml.safe_load(f)
print(stats)

con = duckdb.connect()
trades = con.execute(f"SELECT * FROM '{run}/*.parquet'").df()
print(trades.head())
print(trades["pnl"].describe())
```

## Questions to answer from the trade table

- Why did the strategy enter/exit at each point? Inspect `timestamp` alongside the dataset parquet under the project's `data/` folder for market context.
- Where is PnL concentrated? A strategy carried by one trade is not robust.
- What is the distribution of holding times? Extreme short or long tails often indicate a bug or overfitting.
- How does it compare to buy-and-hold in `stats.yaml`? That comparison is the pass/fail bar.

## Cross-referencing market data

The dataset parquet under `data/` has OHLCV rows. Join on `timestamp` to understand the market regime at each trade — trending, ranging, high-vol.
