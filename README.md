# Steadyline Gold EA

An MQL5 Expert Advisor for automated gold (XAUUSD) trading in MetaTrader 5.

## Project layout

```
MQL5/
  Experts/
    SteadylineGoldEA.mq5   # main Expert Advisor entry point
  Include/
    Steadyline/
      RiskManager.mqh      # position sizing / risk controls
      SignalEngine.mqh     # entry/exit signal logic
      TradeUtils.mqh       # order helpers, trade wrappers
  Presets/
    SteadylineGoldEA.set    # Strategy Tester input preset w/ optimization ranges
docs/
  strategy.md               # strategy notes and rules
  backtesting.md             # connecting to a demo account + Strategy Tester workflow
```

## Getting started

1. Open MetaEditor (bundled with MT5).
2. Copy the `MQL5/` folder contents into your terminal's `MQL5/` data
   directory (`File > Open Data Folder` inside MT5), or symlink this repo's
   `MQL5` folder into it.
3. Open `Experts/SteadylineGoldEA.mq5` in MetaEditor and compile (F7).
4. Attach the compiled EA to an XAUUSD chart in MT5, ideally on a demo
   account first.

See `docs/backtesting.md` for the full demo-account + Strategy Tester
walkthrough, including how to load the input preset and fine-tune via
Optimization without overfitting.

## Status

Early scaffold — strategy logic is a placeholder. See `docs/strategy.md`
for the rules to implement next.

## Disclaimer

This project is for educational and research purposes. Trading gold and
other leveraged instruments carries substantial risk of loss. Always test
on a demo account before running live, and never risk money you cannot
afford to lose.
