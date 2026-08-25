//+------------------------------------------------------------------+
//|                                        SteadylineScalperEA.mq5   |
//|      Fast scalping EA for EURUSD (works on any symbol).          |
//|      Strategy: fast/slow EMA crossover on a low timeframe (M1    |
//|      default), filtered by RSI so entries aren't taken into an   |
//|      already-exhausted move. SL/TP are sized off ATR so they     |
//|      match what price actually does inside the hold window,      |
//|      a spread guard skips trades when cost eats the edge, a      |
//|      cooldown after each close limits overtrading, and a         |
//|      time-based exit stops trades from sitting open past their   |
//|      thesis.                                                     |
//|      This is a starting scaffold, not a validated strategy --    |
//|      backtest and forward-test on a demo account before going    |
//|      live.                                                       |
//+------------------------------------------------------------------+
#property copyright "Steadyline"
#property version   "1.00"
#property strict

#include <Steadyline/ScalpSignalEngine.mqh>
#include <Steadyline/RiskManager.mqh>
#include <Steadyline/TradeUtils.mqh>

//--- inputs
input group "General"
input ulong             InpMagicNumber      = 20260825;
input ulong             InpSlippagePoints   = 10;

input group "Strategy (fast EMA crossover + RSI filter)"
input ENUM_TIMEFRAMES   InpTimeframe        = PERIOD_M1;
input int               InpFastEmaPeriod    = 5;
input int               InpSlowEmaPeriod    = 13;
input int               InpRsiPeriod        = 14;
input double            InpRsiBuyMax        = 70.0;  // skip buys if RSI already above this
input double            InpRsiSellMin       = 30.0;  // skip sells if RSI already below this
input bool              InpReverseSignal    = false; // fade the crossover instead of following it

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
CScalpSignalEngine g_signals;
CRiskManager       g_risk;
CTradeUtils        g_trade;

string             g_symbol;
datetime           g_last_bar_time = 0;
int                g_handle_atr = INVALID_HANDLE;
bool               g_had_position = false;
datetime           g_cooldown_from = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   g_symbol = _Symbol;

   if(!g_signals.Init(g_symbol, InpTimeframe, InpFastEmaPeriod, InpSlowEmaPeriod, InpRsiPeriod))
     {
      Print("SteadylineScalperEA: failed to create indicator handles");
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
   g_signals.Deinit();
   if(g_handle_atr != INVALID_HANDLE)
      IndicatorRelease(g_handle_atr);
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

   ENUM_SIGNAL signal = g_signals.Evaluate(InpRsiBuyMax, InpRsiSellMin);
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
