# Connecting to your demo account & backtesting

This assumes MT5 is already installed on Windows and you can log into a
broker demo account in the terminal. The Strategy Tester backtests using
that broker's own historical price data, so no separate "connection" step
is needed beyond having the demo account logged in.

## 1. Get the files onto your machine and into MT5

Fastest path — from PowerShell:

```powershell
irm https://raw.githubusercontent.com/robnye0-tech/Steadyline/claude/metatrader5-gold-trading-0etqts/scripts/install-mt5.ps1 -OutFile install-mt5.ps1
.\install-mt5.ps1
```

This clones the repo to `$HOME\Steadyline`, auto-detects your MT5 data
folder, and copies `Experts`, `Include\Steadyline`, and `Presets` into
place. See `scripts/install-mt5.ps1` for parameters if you have multiple
MT5 installs or a non-default data folder. Re-run it any time to pull
updates.

Manual alternative: `File > Open Data Folder` in MT5, then copy this
repo's `MQL5\` contents into that folder's `MQL5\` subfolder yourself.

## 2. Compile

1. Open MetaEditor (F4 from MT5, or the toolbar icon).
2. Navigator panel → `Experts\SteadylineScalperEA.mq5` → open it.
3. Compile (F7). Fix any errors before continuing — the Errors tab at the
   bottom will show line numbers. With no changes it should compile clean.
4. Back in MT5, the EA should now appear under
   `Navigator > Expert Advisors > SteadylineScalperEA`.

## 3. Run a single backtest

1. `View > Strategy Tester` (or Ctrl+R).
2. **Expert Advisor**: `SteadylineScalperEA`.
3. **Symbol**: `EURUSD`.
4. **Period**: `M1` (matches the EA's default `InpTimeframe`).
5. **Date range**: start narrow — a week or two — before running a
   long/expensive pass. M1 tick data for a scalper is heavier than the
   H1 data most EAs use.
6. **Model**: `Every tick based on real ticks`. For a scalper this
   matters much more than for a slow strategy — fills, spread, and
   commission accuracy directly determine whether the edge survives
   real trading costs. Expect the first run to spend time downloading
   tick history.
7. **Deposit / currency / leverage**: match your demo account.
8. Symbol properties → set your broker's actual **commission per lot**,
   not just spread, if the Tester doesn't pull it automatically —
   scalping margins are thin enough that commission alone can flip a
   result from profitable to not.
9. Click **Expert properties** → **Inputs** tab → **Load** → select
   `MQL5\Presets\SteadylineScalperEA.set`.
10. **Start**. Check the **Journal** tab for errors, **Graph** for the
    equity curve, and **Report** for the trade-by-trade breakdown.

At M1 with a 20-bar max hold, expect a lot more trades than the old
H1 gold strategy — that's expected for a scalper.

## 4. Fine-tuning via Optimization

The preset file already has ranges for the tunable inputs
(`InpFastEmaPeriod`, `InpSlowEmaPeriod`, `InpRsiPeriod`, `InpRsiBuyMax`,
`InpRsiSellMin`, `InpStopLossPoints`, `InpTakeProfitPoints`,
`InpMaxBarsInTrade`, `InpMaxSpreadPoints`, `InpRiskPercent`). To sweep
them:

1. In the Tester, switch **Optimization** from `Disabled` to
   `Slow complete algorithm` (exhaustive) or `Fast genetic algorithm`
   (faster, approximate — fine once ranges are narrowed).
2. In **Expert properties > Inputs**, tick the checkbox next to each
   parameter you want swept (the `Y`/`N` column, matching the `.set`
   file's optimize flag).
3. Pick an **Optimization criterion** — `Balance max` alone is
   overfit-prone; prefer `Balance + max drawdown`, or `Custom` if you
   want to weight profit factor/drawdown yourself.
4. Run it. Sort **Optimization Results** by your criterion, and check the
   **Optimization Graph** — favor a broad, stable region of good results
   over a single spike. A lone great result surrounded by poor neighbors
   is very likely overfit to that specific date range, which is an even
   bigger risk on M1 data than on H1.

## 5. Avoid overfitting — validate out-of-sample

1. Optimize on one date range (e.g. one month), then re-run a plain
   (non-optimizing) backtest of the winning parameters on a different
   month it never saw.
2. If performance collapses out-of-sample, the parameters were likely
   fit to noise — go with a more conservative, stable combination.
3. Once you're happy, forward-test by attaching the EA to a live demo
   EURUSD chart (`Algo Trading` enabled) and letting it trade in real
   time for a while before considering a live account.

## Notes

- The daily-loss guard (`InpMaxDailyLossPercent`) and the time-based
  exit (`InpMaxBarsInTrade`) both use simulated time in the Tester, so
  they behave the same in backtests as they do live.
- If the Tester reports very few or zero trades, double-check the
  `InpMaxSpreadPoints` guard isn't filtering out every bar — widen it
  temporarily to confirm the strategy logic itself is firing before
  tightening it back down.
