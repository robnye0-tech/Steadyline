# Connecting to your demo account & backtesting

This assumes MT5 is already installed on Windows and you can log into a
broker demo account in the terminal. The Strategy Tester backtests using
that broker's own historical price data, so no separate "connection" step
is needed beyond having the demo account logged in.

## 1. Get the files into MT5's data folder

1. In MT5: `File > Open Data Folder`. This opens Explorer at your
   terminal's data directory (something like
   `C:\Users\<you>\AppData\Roaming\MetaQuotes\Terminal\<hash>\`).
2. Copy this repo's `MQL5` folder contents into that folder's `MQL5\`
   subfolder, merging so you end up with:
   ```
   <data folder>\MQL5\Experts\SteadylineGoldEA.mq5
   <data folder>\MQL5\Include\Steadyline\*.mqh
   <data folder>\MQL5\Presets\SteadylineGoldEA.set
   ```
   (Easiest: copy `MQL5\Experts`, `MQL5\Include\Steadyline`, and
   `MQL5\Presets` into the corresponding existing folders.)

## 2. Compile

1. Open MetaEditor (F4 from MT5, or the toolbar icon).
2. Navigator panel → `Experts\SteadylineGoldEA.mq5` → open it.
3. Compile (F7). Fix any errors before continuing — the Errors tab at the
   bottom will show line numbers. With no changes it should compile clean.
4. Back in MT5, the EA should now appear under
   `Navigator > Expert Advisors > SteadylineGoldEA`.

## 3. Confirm the gold symbol name

Brokers name gold differently — `XAUUSD`, `XAUUSD.m`, `GOLD`, `XAUUSDm`,
etc. Check Market Watch (Ctrl+M) for the exact symbol your demo account
uses; you'll select it in the Tester. The EA reads point size and tick
value dynamically via `SymbolInfoDouble`, so it doesn't need code changes
for a different symbol name — just pick the right one in the Tester.

## 4. Run a single backtest

1. `View > Strategy Tester` (or Ctrl+R).
2. **Expert Advisor**: `SteadylineGoldEA`.
3. **Symbol**: your broker's gold symbol from step 3.
4. **Period**: `H1` (matches the EA's default `InpTimeframe`; if you
   change `InpTimeframe`, the chart period field here doesn't need to
   match — the EA reads its own timeframe internally).
5. **Date range**: start narrow to sanity-check first — e.g. the last 3
   months — before running a long/expensive pass.
6. **Model**: `Every tick based on real ticks` for the most realistic
   fills (slower, downloads tick history the first time). `1 minute OHLC`
   is faster but less accurate for an EA that only acts on bar close,
   which is a reasonable tradeoff for quick iteration.
7. **Deposit / currency / leverage**: match your demo account so position
   sizing behaves like it would live.
8. Click **Expert properties** → **Inputs** tab → **Load** → select
   `MQL5\Presets\SteadylineGoldEA.set`.
9. **Start**. Check the **Journal** tab for errors, **Graph** for the
   equity curve, and **Report** for the trade-by-trade breakdown.

If it runs clean with zero or very few trades, widen the date range —
this strategy only trades on EMA crossovers filtered by the 200-period
trend EMA, so signals are infrequent on H1.

## 5. Fine-tuning via Optimization

The preset file already has sensible ranges for the tunable inputs
(`InpFastEmaPeriod`, `InpSlowEmaPeriod`, `InpTrendEmaPeriod`,
`InpStopLossPoints`, `InpTakeProfitPoints`, `InpRiskPercent`). To sweep
them:

1. In the Tester, switch the **Optimization** dropdown from `Disabled` to
   `Slow complete algorithm` (exhaustive) or `Fast genetic algorithm`
   (faster, approximate — fine once you've narrowed ranges).
2. In **Expert properties > Inputs**, tick the checkbox next to each
   parameter you want swept (this is the `Y`/`N` column — matches the
   `.set` file's optimize flag).
3. Pick an **Optimization criterion** — `Balance max` alone is
   overfit-prone; prefer `Balance + max drawdown` or a `Custom` criterion
   if you want to weight drawdown/profit factor yourself.
4. Run it. Check the **Optimization Results** tab, sorted by your chosen
   criterion, and look at the **Optimization Graph** (2D/3D chart) —
   favor a broad, stable region of good results over a single spike.
   A lone great result surrounded by poor neighbors is very likely
   overfit to that specific date range.

## 6. Avoid overfitting — validate out-of-sample

Don't trust a parameter set just because it backtested well on the exact
range you optimized against:

1. Split your history in two, e.g. optimize on 2023, then re-run a plain
   (non-optimizing) backtest of the winning parameters on 2024 data it
   never saw.
2. If performance collapses out-of-sample, the parameters were likely
   fit to noise — go with a more conservative, stable combination instead
   of the single best in-sample result.
3. Once you're happy, forward-test by attaching the EA to a live demo
   chart (`Algo Trading` button enabled) and letting it trade in real
   time for a while before considering a live account.

## Notes

- The daily-loss guard (`InpMaxDailyLossPercent`) uses `TimeCurrent()`,
  which reflects simulated time during backtests, so it behaves
  correctly in the Tester (not just live).
- Every tick data for gold over a long range can take a while to
  download the first time — that's a one-time cost per date range per
  symbol, cached by the terminal afterward.
