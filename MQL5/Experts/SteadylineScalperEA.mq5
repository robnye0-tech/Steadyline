//+------------------------------------------------------------------+
//|                                        SteadylineScalperEA.mq5   |
//|      Scalping EA for EURUSD (works on any symbol) with three     |
//|      selectable, structurally distinct entry models -- pick one  |
//|      via InpStrategyMode and backtest each independently rather  |
//|      than assuming any one of them has a real edge:              |
//|        0 EMA crossover + RSI filter    (momentum-following)      |
//|        1 Bollinger Band mean-reversion (fade band extremes)      |
//|        2 Higher-TF trend + Stochastic pullback (trend-following) |
//|      SL/TP are sized off ATR so they match what price actually   |
//|      does inside the hold window, a spread guard skips trades    |
//|      when cost eats the edge, a cooldown after each close limits |
//|      overtrading, a session filter restricts entries to a        |
//|      configurable hour window, and a time-based exit stops       |
//|      trades from sitting open past their thesis.                 |
//|      This is a starting scaffold, not a validated strategy --    |
//|      backtest and forward-test on a demo account before going    |
//|      live.                                                       |
//+------------------------------------------------------------------+
#property copyright "Steadyline"
#property version   "2.00"
#property strict

#include <Steadyline/Signal.mqh>
#include <Steadyline/ScalpSignalEngine.mqh>
#include <Steadyline/MeanReversionSignalEngine.mqh>
#include <Steadyline/TrendPullbackSignalEngine.mqh>
#include <Steadyline/RiskManager.mqh>
#include <Steadyline/TradeUtils.mqh>

enum ENUM_STRATEGY_MODE
  {
   STRAT_EMA_CROSS      = 0, // EMA crossover + RSI filter
   STRAT_BB_MEANREV     = 1, // Bollinger Band mean-reversion
   STRAT_TREND_PULLBACK = 2  // Higher-TF trend + Stochastic pullback
  };

//--- inputs
input group "General"
input ulong             InpMagicNumber      = 20260825;
input ulong             InpSlippagePoints   = 10;

input group "Strategy selection"
input ENUM_STRATEGY_MODE InpStrategyMode    = STRAT_EMA_CROSS;
input ENUM_TIMEFRAMES   InpTimeframe        = PERIOD_M1;   // entry timeframe, used by all modes
input bool              InpReverseSignal    = false;       // flip buy/sell for whichever mode is active

input group "Strategy 0: EMA crossover + RSI filter"
input int               InpFastEmaPeriod    = 5;
input int               InpSlowEmaPeriod    = 13;
input int               InpRsiPeriod        = 14;
input double            InpRsiBuyMax        = 70.0;  // skip buys if RSI already above this
input double            InpRsiSellMin       = 30.0;  // skip sells if RSI already below this

input group "Strategy 1: Bollinger Band mean-reversion"
input int               InpBbPeriod         = 20;
input double            InpBbDeviation      = 2.0;
input double            InpBbRsiOversold    = 30.0;  // confirm a lower-band close with RSI below this
input double            InpBbRsiOverbought  = 70.0;  // confirm an upper-band close with RSI above this

input group "Strategy 2: Higher-TF trend + Stochastic pullback"
input ENUM_TIMEFRAMES   InpTrendTimeframe   = PERIOD_H1;
input int               InpTrendEmaPeriod   = 50;
input int               InpStochKPeriod     = 5;
input int               InpStochDPeriod     = 3;
input int               InpStochSlowing     = 3;
input double            InpStochOversold    = 20.0;
input double            InpStochOverbought  = 80.0;

input group "Session filter (broker/server time)"
input bool              InpUseSessionFilter = true;
input int               InpSessionStartHour = 7;     // inclusive, 0-23
input int               InpSessionEndHour   = 19;    // exclusive, 0-23

input group "Trade management (ATR-based SL/TP)"
input int               InpAtrPeriod        = 14;
input double            InpSlAtrMultiplier  = 1.0;   // stop distance = ATR * this
input double            InpTpAtrMultiplier  = 1.5;   // target distance = ATR * this
input int               InpMaxBarsInTrade   = 20;    // force-close if still open after this many bars

input group "Cost guard"
input int               InpMaxSpreadPoints  = 20;    // skip entries when current spread exceeds this
input int               InpCooldownBars     = 5;     // bars to wait after a close before a new entry

input group "Risk"
input double            InpRiskPercent         = 0.5;  // % of equity risked per trade
input double            InpMaxDailyLossPercent = 3.0;  // halt new trades once daily loss reaches this

//--- globals
CScalpSignalEngine          g_emaCross;
CMeanReversionSignalEngine  g_meanRev;
CTrendPullbackSignalEngine  g_trendPullback;
CRiskManager                g_risk;
CTradeUtils                 g_trade;

string             g_symbol;
datetime           g_last_bar_time = 0;
int                g_handle_atr = INVALID_HANDLE;
bool               g_had_position = false;
datetime           g_cooldown_from = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   g_symbol = _Symbol;

   bool signalsOk = false;
   switch(InpStrategyMode)
     {
      case STRAT_EMA_CROSS:
         signalsOk = g_emaCross.Init(g_symbol, InpTimeframe, InpFastEmaPeriod, InpSlowEmaPeriod, InpRsiPeriod);
         break;
      case STRAT_BB_MEANREV:
         signalsOk = g_meanRev.Init(g_symbol, InpTimeframe, InpBbPeriod, InpBbDeviation, InpRsiPeriod);
         break;
      case STRAT_TREND_PULLBACK:
         signalsOk = g_trendPullback.Init(g_symbol, InpTimeframe, InpTrendTimeframe, InpTrendEmaPeriod,
                                           InpStochKPeriod, InpStochDPeriod, InpStochSlowing);
         break;
     }

   if(!signalsOk)
     {
      Print("SteadylineScalperEA: failed to create indicator handles for strategy mode ", EnumToString(InpStrategyMode));
      return INIT_FAILED;
     }

   g_handle_atr = iATR(g_symbol, InpTimeframe, InpAtrPeriod);
   if(g_handle_atr == INVALID_HANDLE)
     {
      Print("SteadylineScalperEA: failed to create ATR handle");
      return INIT_FAILED;
     }

   g_risk.Init(g_symbol, InpRiskPercent, InpMaxDailyLossPercent);
   g_trade.Init(g_symbol, InpMagicNumber, InpSlippagePoints);

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_emaCross.Deinit();
   g_meanRev.Deinit();
   g_trendPullback.Deinit();
   if(g_handle_atr != INVALID_HANDLE)
      IndicatorRelease(g_handle_atr);
  }

//+------------------------------------------------------------------+
ENUM_SIGNAL EvaluateActiveStrategy()
  {
   switch(InpStrategyMode)
     {
      case STRAT_EMA_CROSS:
         return g_emaCross.Evaluate(InpRsiBuyMax, InpRsiSellMin);
      case STRAT_BB_MEANREV:
         return g_meanRev.Evaluate(InpBbRsiOversold, InpBbRsiOverbought);
      case STRAT_TREND_PULLBACK:
         return g_trendPullback.Evaluate(InpStochOversold, InpStochOverbought);
     }
   return SIGNAL_NONE;
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   g_risk.RefreshDailyBaseline();

   //--- only evaluate once per new closed bar, not on every tick
   datetime barTime = iTime(g_symbol, InpTimeframe, 0);
   bool isNewBar = (barTime != g_last_bar_time);
   if(isNewBar)
      g_last_bar_time = barTime;

   bool hasPosition = g_trade.HasOpenPosition();
   if(g_had_position && !hasPosition)
      g_cooldown_from = barTime;
   g_had_position = hasPosition;

   if(hasPosition)
     {
      ManageOpenPosition();
      return;
     }

   if(!isNewBar)
      return;

   if(g_risk.DailyLossLimitHit())
     {
      Comment("SteadylineScalperEA: daily loss limit reached, trading paused");
      return;
     }

   if(InpCooldownBars > 0 && g_cooldown_from != 0)
     {
      int barsSinceClose = iBarShift(g_symbol, InpTimeframe, g_cooldown_from);
      if(barsSinceClose < InpCooldownBars)
         return;
     }

   if(InpUseSessionFilter && !IsWithinSession())
      return;

   long spreadPoints = SymbolInfoInteger(g_symbol, SYMBOL_SPREAD);
   if(spreadPoints > InpMaxSpreadPoints)
      return;

   ENUM_SIGNAL signal = EvaluateActiveStrategy();
   if(signal == SIGNAL_NONE)
      return;

   if(InpReverseSignal)
      signal = (signal == SIGNAL_BUY) ? SIGNAL_SELL : SIGNAL_BUY;

   double atr[1];
   if(CopyBuffer(g_handle_atr, 0, 1, 1, atr) != 1 || atr[0] <= 0.0)
      return;

   double ask    = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   double slDist = atr[0] * InpSlAtrMultiplier;
   double tpDist = atr[0] * InpTpAtrMultiplier;

   double lots = g_risk.LotsForStopDistance(slDist);
   if(lots <= 0.0)
     {
      Print("SteadylineScalperEA: computed lot size is zero, skipping trade");
      return;
     }

   if(signal == SIGNAL_BUY)
     {
      double sl = ask - slDist;
      double tp = ask + tpDist;
      g_trade.OpenBuy(lots, sl, tp, "SteadylineScalperEA buy");
     }
   else if(signal == SIGNAL_SELL)
     {
      double sl = bid + slDist;
      double tp = bid - tpDist;
      g_trade.OpenSell(lots, sl, tp, "SteadylineScalperEA sell");
     }
  }

//+------------------------------------------------------------------+
//| Whether the current broker/server hour falls inside the allowed  |
//| trading window. Handles a window that wraps past midnight.       |
//+------------------------------------------------------------------+
bool IsWithinSession()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);

   if(InpSessionStartHour <= InpSessionEndHour)
      return (tm.hour >= InpSessionStartHour && tm.hour < InpSessionEndHour);

   return (tm.hour >= InpSessionStartHour || tm.hour < InpSessionEndHour);
  }

//+------------------------------------------------------------------+
//| Force-close a scalp that has overstayed its welcome, even if it  |
//| hasn't hit SL/TP yet -- a scalp thesis goes stale fast.          |
//+------------------------------------------------------------------+
void ManageOpenPosition()
  {
   if(InpMaxBarsInTrade <= 0)
      return;

   datetime openTime = g_trade.PositionOpenTime();
   if(openTime == 0)
      return;

   int barsOpen = iBarShift(g_symbol, InpTimeframe, openTime);
   if(barsOpen >= InpMaxBarsInTrade)
      g_trade.CloseAll();
  }
//+------------------------------------------------------------------+
