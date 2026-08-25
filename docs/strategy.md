# Strategy notes — Steadyline Scalper EA

## Current placeholder strategy

Fast EMA crossover on EURUSD (works on any symbol), filtered by RSI, on a
low timeframe (default M1):

- Fast EMA (default 5) crosses above Slow EMA (default 13) **and** RSI is
  below `InpRsiBuyMax` (default 70, i.e. not already overbought) → buy.
- Fast EMA crosses below Slow EMA **and** RSI is above `InpRsiSellMin`
  (default 30, i.e. not already oversold) → sell.
- One position at a time. Entries evaluated once per closed bar on the
  EA's timeframe; open positions are managed on every tick.

Exits are:
- A stop-loss/take-profit sized off current volatility: distance =
  ATR(`InpAtrPeriod`) × `InpSlAtrMultiplier` / `InpTpAtrMultiplier`,
  recomputed at the moment each trade opens.
- A **time-based exit**: if the position is still open after
  `InpMaxBarsInTrade` bars (default 20), it's force-closed regardless of
  P&L — a scalp thesis goes stale fast, so this avoids a small loser
  turning into a large one by drifting for hours.

## Cost guards

Scalping lives and dies on transaction cost:
- `InpMaxSpreadPoints` skips new entries whenever the current spread
  exceeds that threshold — without it, a strategy that looks profitable
  in backtests (which may model spread optimistically) can bleed out
  live when spread widens around news or thin liquidity.
- `InpCooldownBars` blocks new entries for that many bars after any
  position closes. Without it, a fast crossover-based strategy can churn
  through far more trades than it has edge to pay spread on — see the
  postmortem below.

## Postmortem: why the first backtest lost steadily

A first backtest with fixed 100/150-point SL/TP and no cooldown produced
6,920 trades with a profit factor of 0.78 and a smooth, steady equity
decline (not one blowup — a slow bleed). The tell: average win ($9.13)
and average loss ($9.47) were nearly identical, despite a nominal 1.5:1
TP:SL ratio. That only happens when most trades aren't reaching either
SL or TP — they're being closed by the time-based exit at a roughly
random price. Two structural causes, both now addressed above:
1. Fixed 100/150-point distances didn't match what EURUSD actually moves
   within a 20-bar M1 window, so ATR-based sizing replaces them.
2. One trade roughly every 34 minutes was far too much churn for a
   fixed-cost-per-trade strategy — `InpCooldownBars` cuts frequency.

Re-run the backtest after this change before trusting any further
parameter tuning — if it's still losing steadily rather than choppily,
the entry logic itself (not just sizing/frequency) needs rework.

## Risk management

- Position size is computed from `InpRiskPercent` (% of account equity)
  and the stop-loss distance, via `CRiskManager::LotsForStopDistance`.
- `InpMaxDailyLossPercent` halts new entries for the rest of the broker
  day once equity drawdown from the day's starting equity reaches that
  threshold. Existing positions are not force-closed by this guard.

## Known gaps / next steps

- [ ] Backtest on **Every tick based on real ticks** model — for an M1
      scalper, cheaper models (OHLC) can meaningfully misstate fills and
      spread cost. Expect the tick-history download to take a while for
      long ranges.
- [ ] Commission modeling: set your broker's actual commission-per-lot in
      the Tester's symbol properties, not just spread — scalping margins
      are thin enough that commission alone can flip a strategy
      unprofitable.
- [ ] Session filter: EURUSD scalping edge is heavily concentrated around
      London open and the London/NY overlap; a flat/quiet Asian session
      can generate noise trades. Consider adding a trading-hours input.
- [ ] News filter: EURUSD scalps are exposed to red-flag volatility
      spikes around high-impact news (NFP, CPI, FOMC) — the fixed SL can
      be jumped by slippage during those windows.
- [ ] Slippage/requote handling: `InpSlippagePoints` (deviation) is set
      tight for scalping — verify it isn't causing rejected orders on
      your broker's execution model.

## Disclaimer

Nothing here is financial advice. Validate any strategy change with
backtesting and demo forward-testing before risking real capital.
Scalping in particular is unforgiving of execution-cost assumptions that
don't hold up live — treat backtest results with extra skepticism until
confirmed on a demo account under realistic spread/commission.
