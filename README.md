# Steadyline Scalper EA

An MQL5 Expert Advisor for fast EURUSD scalping in MetaTrader 5 (works on
any symbol you attach it to).

## Project layout

```
MQL5/
  Experts/
    SteadylineScalperEA.mq5  # main Expert Advisor entry point
  Include/
    Steadyline/
      RiskManager.mqh        # position sizing / risk controls
      ScalpSignalEngine.mqh  # entry signal logic (EMA crossover + RSI filter)
      TradeUtils.mqh         # order helpers, trade wrappers
  Presets/
    SteadylineScalperEA.set  # Strategy Tester input preset w/ optimization ranges
docs/
  strategy.md                # strategy notes and rules
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

Early scaffold — strategy logic is a placeholder. See `docs/strategy.md`
for the rules to implement next.

## Disclaimer

This project is for educational and research purposes. Trading forex and
other leveraged instruments carries substantial risk of loss. Scalping
in particular is highly sensitive to spread and commission — always test
on a demo account before running live, and never risk money you cannot
afford to lose.
