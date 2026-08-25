# Steadyline Scalper EA

An MQL5 Expert Advisor for fast EURUSD scalping in MetaTrader 5 (works on
any symbol you attach it to). Ships with three selectable, structurally
distinct entry strategies (`InpStrategyMode`) so you can empirically test
which one — if any — actually has an edge, rather than trusting a single
hard-coded approach.

## Project layout

```
MQL5/
  Experts/
    SteadylineScalperEA.mq5          # main Expert Advisor entry point
  Include/
    Steadyline/
      Signal.mqh                     # shared ENUM_SIGNAL type
      ScalpSignalEngine.mqh          # strategy 0: EMA crossover + RSI filter
      MeanReversionSignalEngine.mqh  # strategy 1: Bollinger Band mean-reversion
      TrendPullbackSignalEngine.mqh  # strategy 2: higher-TF trend + Stochastic pullback
      RiskManager.mqh                # position sizing / risk controls
      TradeUtils.mqh                 # order helpers, trade wrappers
  Presets/
    SteadylineScalperEA.set  # Strategy Tester input preset w/ optimization ranges
docs/
  strategy.md                # what each strategy does, and the backtest postmortems so far
  backtesting.md              # connecting to a demo account + Strategy Tester workflow
scripts/
  install-mt5.ps1             # PowerShell: pull this repo and install into your MT5 data folder
```

## Getting started (Windows)

From PowerShell:

```powershell
irm https://raw.githubusercontent.com/robnye0-tech/Steadyline/claude/metatrader5-gold-trading-0etqts/scripts/install-mt5.ps1 -OutFile install-mt5.ps1
.\install-mt5.ps1
```

This clones the repo and copies the EA into your MT5 data folder
automatically. Then in MT5/MetaEditor:

1. Open MetaEditor, compile `Experts\SteadylineScalperEA.mq5` (F7).
2. Open a EURUSD chart in MT5.
3. Enable the **AutoTrading** button in the toolbar.
4. Drag `SteadylineScalperEA` from `Navigator > Expert Advisors` onto the
   chart.
5. In the dialog: **Common** tab → check **Allow Algo Trading**;
   **Inputs** tab → **Load** → `Presets\SteadylineScalperEA.set`.

See `docs/backtesting.md` for the full demo-account + Strategy Tester
walkthrough, including how to fine-tune via Optimization without
overfitting.

## Status

Backtesting in progress. Two of the three strategies are untested so
far; the EMA-crossover mode has been through several rounds of backtest
→ diagnosis → fix and currently shows a weak negative edge (profit
factor ~0.8–0.9 depending on settings) — see `docs/strategy.md` for the
full postmortem history and what to test next.

## Disclaimer

This project is for educational and research purposes. Trading forex and
other leveraged instruments carries substantial risk of loss. Scalping
in particular is highly sensitive to spread and commission — always test
on a demo account before running live, and never risk money you cannot
afford to lose.
