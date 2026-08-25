//+------------------------------------------------------------------+
//|                                        SteadylineScalperEA.mq5   |
//|      Fast scalping EA for EURUSD (works on any symbol).          |
//|      Strategy: fast/slow EMA crossover on a low timeframe (M1    |
//|      default), filtered by RSI so entries aren't taken into an   |
//|      already-exhausted move. Small fixed SL/TP, a spread guard   |
//|      so trades aren't taken when the cost eats the edge, and a   |
//|      time-based exit so trades don't sit open past their thesis. |
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

input group "Trade management"
input double            InpStopLossPoints   = 100;   // e.g. 100 points = 10 pips on a 5-digit EURUSD
input double            InpTakeProfitPoints = 150;
input int               InpMaxBarsInTrade   = 20;    // force-close if still open after this many bars

input group "Cost guard"
input int               InpMaxSpreadPoints  = 20;    // skip entries when current spread exceeds this

input group "Risk"
input double            InpRiskPercent         = 0.5;  // % of equity risked per trade
input double            InpMaxDailyLossPercent = 3.0;  // halt new trades once daily loss reaches this

//--- globals
CScalpSignalEngine g_signals;
CRiskManager       g_risk;
CTradeUtils        g_trade;

string             g_symbol;
datetime           g_last_bar_time = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   g_symbol = _Symbol;

   if(!g_signals.Init(g_symbol, InpTimeframe, InpFastEmaPeriod, InpSlowEmaPeriod, InpRsiPeriod))
     {
      Print("SteadylineScalperEA: failed to create indicator handles");
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

   if(g_trade.HasOpenPosition())
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

   long spreadPoints = SymbolInfoInteger(g_symbol, SYMBOL_SPREAD);
   if(spreadPoints > InpMaxSpreadPoints)
      return;

   ENUM_SIGNAL signal = g_signals.Evaluate(InpRsiBuyMax, InpRsiSellMin);
   if(signal == SIGNAL_NONE)
      return;

   double point  = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   double ask    = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   double slDist = InpStopLossPoints * point;
   double tpDist = InpTakeProfitPoints * point;

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
