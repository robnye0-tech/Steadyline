# Strategy notes — Steadyline Scalper EA

## On "proven" strategies

There's no registry of verified, durable EURUSD edges to draw from —
almost everything marketed as a "proven strategy" is backtested-only,
fit to one period, or simply unverifiable. What this EA does instead is
give you **three structurally distinct, well-understood entry models**
selectable via `InpStrategyMode`, sharing the same risk/exit machinery,
so you can empirically test which one (if any) actually holds up on
your broker's data — rather than trusting a name or a claim. Treat every
result the same skeptical way we've treated the last three backtests:
a number from the Tester, not a verdict, until it survives out-of-sample
data too (see the fine-tuning workflow in `docs/backtesting.md`).

## Strategy 0: EMA crossover + RSI filter (momentum-following)

- Fast EMA (`InpFastEmaPeriod`, default 5) crosses above Slow EMA
  (`InpSlowEmaPeriod`, default 13) **and** RSI is below `InpRsiBuyMax`
  (not already overbought) → buy. Mirror logic for sell.
- Bets that a fresh crossover marks the start of a short-term move.
- **Backtested result on this account/period: profit factor 0.77–0.80,
  win rate ~31–34%** — weak-to-no edge as specified. See Postmortems 1–2
  below for how we got here.

## Strategy 1: Bollinger Band mean-reversion (fade extremes)

- Price closes at/beyond the lower Bollinger Band (`InpBbPeriod`,
  `InpBbDeviation`) **and** RSI confirms oversold (below
  `InpBbRsiOversold`) → buy, betting on reversion back toward the mean.
  Mirror logic for sell at the upper band.
- Motivated directly by what reversing Strategy 0 showed: fading
  momentum outperformed following it (profit factor 0.80 → 0.91,
  drawdown 97% → 82% just from flipping buy/sell). This strategy is a
  more deliberate, purpose-built version of that same idea rather than
  an accidental one.

## Strategy 2: Higher-timeframe trend + Stochastic pullback (trend-following)

- `InpTrendTimeframe` (default H1) EMA (`InpTrendEmaPeriod`, default 50)
  sets the direction: price above it = uptrend, below = downtrend.
- On the entry timeframe, a Stochastic %K swinging back up out of
  oversold (`InpStochOversold`) times a buy in an uptrend; swinging back
  down out of overbought (`InpStochOverbought`) times a sell in a
  downtrend.
- Different premise from the other two: don't predict direction from the
  entry timeframe at all, take it from a higher timeframe, and only use
  the fast timeframe to time entries in that direction. Worth testing
  because M1-only signals (both 0 and 1) are noisy — this deliberately
  filters out counter-trend noise using a timeframe one level up.

## Shared machinery (applies to whichever strategy is active)

- `InpReverseSignal` flips buy/sell for the active strategy — cheap way
  to A/B test "follow vs. fade" on any of the three without touching
  code.
- Exit: ATR-based stop/target — distance = ATR(`InpAtrPeriod`) ×
  `InpSlAtrMultiplier` / `InpTpAtrMultiplier`, recomputed per trade —
  plus a **time-based exit**: still open after `InpMaxBarsInTrade` bars
  and it's force-closed regardless of P&L.
- `InpMaxSpreadPoints` skips entries when spread is too wide.
- `InpCooldownBars` blocks new entries for that many bars after any
  close, capping overtrading.
- `InpUseSessionFilter` / `InpSessionStartHour` / `InpSessionEndHour`
  restrict entries to a configurable hour window (broker/server time).
- Position size from `InpRiskPercent` of equity and the stop distance,
  via `CRiskManager::LotsForStopDistance`. `InpMaxDailyLossPercent`
  halts new entries for the rest of the broker day past that drawdown.

One position at a time; entries evaluated once per closed bar on
`InpTimeframe`, open positions managed every tick.

## Postmortem 1: why the first backtest lost steadily

A first backtest with fixed 100/150-point SL/TP and no cooldown produced
6,920 trades with a profit factor of 0.78 and a smooth, steady equity
decline (not one blowup — a slow bleed). The tell: average win ($9.13)
and average loss ($9.47) were nearly identical, despite a nominal 1.5:1
TP:SL ratio. That only happens when most trades aren't reaching either
SL or TP — they're being closed by the time-based exit at a roughly
random price. Two structural causes:
1. Fixed 100/150-point distances didn't match what EURUSD actually moves
   within a 20-bar M1 window → replaced with ATR-based sizing.
2. One trade roughly every 34 minutes was far too much churn for a
   fixed-cost-per-trade strategy → `InpCooldownBars` cuts frequency.

## Postmortem 2: ATR sizing worked, the signal itself didn't

With ATR-based SL/TP and a cooldown, the second backtest dropped to
3,698 trades and average win ($29.25) came out to ~1.7x average loss
($17.26) — proof trades were now actually reaching SL/TP instead of the
time exit. But win rate was only 31.37%, profit factor stayed at 0.77,
drawdown ballooned to ~99%. A payoff ratio can't rescue a signal that's
wrong two-thirds of the time.

The hourly breakdown showed entries and losses concentrated in the
Asian session (hours 0–4 in the Tester's report) → session filter added.
**The right start/end hours depend on your broker's server time offset**
— compare against the Tester's "Entries by hours" / "Profits and losses
by hours" report to find where losses actually cluster for your broker
rather than trusting the defaults (7–19) blindly.

## Postmortem 3: reversing the signal helped, confirming the hunch

Session filter alone only nudged things (profit factor 0.77 → 0.80,
drawdown ~99% → ~97%). Reversing the EMA-cross signal on top of that
did much more: profit factor 0.80 → **0.91**, drawdown ~97% → **82%**,
win rate 32.7% → 37.3%. Still net-losing overall, but a real, consistent
improvement from one flip — the clearest evidence yet that this
instrument/timeframe favors fading short-term momentum over following
it. That's what motivated building Strategy 1 (mean-reversion) and
Strategy 2 (trend-following on a *higher* timeframe, sidestepping the
M1-momentum question entirely) as deliberate, testable alternatives
instead of continuing to tune Strategy 0's dials.

## Known gaps / next steps

- [ ] Backtest on **Every tick based on real ticks** model — for an M1
      scalper, cheaper models (OHLC) can meaningfully misstate fills and
      spread cost. Expect the tick-history download to take a while for
      long ranges.
- [ ] Commission modeling: set your broker's actual commission-per-lot in
      the Tester's symbol properties, not just spread — scalping margins
      are thin enough that commission alone can flip a strategy
      unprofitable.
- [ ] News filter: EURUSD scalps are exposed to red-flag volatility
      spikes around high-impact news (NFP, CPI, FOMC) — the ATR stop can
      still be jumped by slippage during those windows.
- [ ] Slippage/requote handling: `InpSlippagePoints` (deviation) is set
      tight for scalping — verify it isn't causing rejected orders on
      your broker's execution model.
- [ ] If none of the three strategies show a durable edge after proper
      out-of-sample validation, that itself is a useful (if
      unglamorous) result — it likely means EURUSD M1 doesn't have
      enough exploitable structure for a simple indicator-based system,
      and a longer timeframe or a fundamentally different data source
      (order flow, volume profile) would be needed.

## Disclaimer

Nothing here is financial advice. Validate any strategy change with
backtesting and demo forward-testing before risking real capital.
Scalping in particular is unforgiving of execution-cost assumptions that
don't hold up live — treat backtest results with extra skepticism until
confirmed on a demo account under realistic spread/commission.
