# Strategy notes — Steadyline Gold EA

## Current placeholder strategy

EMA crossover on XAUUSD, filtered by a longer-term trend EMA:

- Fast EMA (default 12) crosses above Slow EMA (default 26) **and** the
  previous close is above the Trend EMA (default 200) → buy.
- Fast EMA crosses below Slow EMA **and** the previous close is below the
  Trend EMA → sell.
- One position at a time. Evaluated once per closed bar on the EA's
  timeframe (default H1), not on every tick.

Exits are a fixed stop-loss/take-profit in points, set on order open.
No trailing stop or partial-close logic yet.

## Risk management

- Position size is computed from `InpRiskPercent` (% of account equity)
  and the stop-loss distance, via `CRiskManager::LotsForStopDistance`.
- `InpMaxDailyLossPercent` halts new entries for the rest of the broker
  day once equity drawdown from the day's starting equity reaches that
  threshold. Existing positions are not force-closed by this guard.

## Known gaps / next steps

- [ ] Backtest across multiple XAUUSD regimes (trending vs. ranging,
      high/low volatility) in the MT5 Strategy Tester before any live use.
- [ ] Tune `InpStopLossPoints` / `InpTakeProfitPoints` against actual
      broker digits/point size for gold (varies by broker — verify
      `SymbolInfoDouble(_Symbol, SYMBOL_POINT)` before trusting defaults).
- [ ] Consider session/time-of-day filters — gold volatility differs a lot
      around London/NY opens vs. Asian session.
- [ ] Consider ATR-based stops instead of fixed points, since gold's
      volatility regime shifts significantly over time.
- [ ] Add spread/slippage guard before entry (gold spreads can widen
      sharply around news).
- [ ] Decide on trailing-stop or partial take-profit logic.

## Disclaimer

Nothing here is financial advice. Validate any strategy change with
backtesting and demo forward-testing before risking real capital.
