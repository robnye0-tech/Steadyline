//+------------------------------------------------------------------+
//|                                            SteadylineGoldEA.mq5  |
//|      Expert Advisor for automated XAUUSD trading in MT5.         |
//|      Strategy: EMA crossover filtered by a longer-term trend     |
//|      EMA, with fixed-percent risk sizing and a daily loss guard. |
//|      This is a starting scaffold, not a validated strategy --    |
//|      backtest and forward-test on a demo account before going    |
//|      live.                                                       |
//+------------------------------------------------------------------+
#property copyright "Steadyline"
#property version   "1.00"
#property strict

#include <Steadyline/SignalEngine.mqh>
#include <Steadyline/RiskManager.mqh>
#include <Steadyline/TradeUtils.mqh>

//--- inputs
input group "General"
input ulong             InpMagicNumber      = 20260825;
input ulong             InpSlippagePoints   = 20;

input group "Strategy (EMA crossover)"
input ENUM_TIMEFRAMES   InpTimeframe        = PERIOD_H1;
input int               InpFastEmaPeriod    = 12;
input int               InpSlowEmaPeriod    = 26;
input int               InpTrendEmaPeriod   = 200;

input group "Trade management"
input double            InpStopLossPoints   = 3000;   // XAUUSD quoted in points; tune to broker digits
input double            InpTakeProfitPoints = 6000;

input group "Risk"
input double            InpRiskPercent        = 0.5;  // % of equity risked per trade
input double            InpMaxDailyLossPercent = 3.0;  // halt new trades once daily loss reaches this

//--- globals
CSignalEngine g_signals;
CRiskManager  g_risk;
CTradeUtils   g_trade;

string        g_symbol;
datetime      g_last_bar_time = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   g_symbol = _Symbol;

   if(!g_signals.Init(g_symbol, InpTimeframe, InpFastEmaPeriod, InpSlowEmaPeriod, InpTrendEmaPeriod))
     {
      Print("SteadylineGoldEA: failed to create indicator handles");
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
   if(barTime == g_last_bar_time)
      return;
   g_last_bar_time = barTime;

   if(g_risk.DailyLossLimitHit())
     {
      Comment("SteadylineGoldEA: daily loss limit reached, trading paused");
      return;
     }

   if(g_trade.HasOpenPosition())
      return;

   ENUM_SIGNAL signal = g_signals.Evaluate();
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
      Print("SteadylineGoldEA: computed lot size is zero, skipping trade");
      return;
     }

   if(signal == SIGNAL_BUY)
     {
      double sl = ask - slDist;
      double tp = ask + tpDist;
      g_trade.OpenBuy(lots, sl, tp, "SteadylineGoldEA buy");
     }
   else if(signal == SIGNAL_SELL)
     {
      double sl = bid + slDist;
      double tp = bid - tpDist;
      g_trade.OpenSell(lots, sl, tp, "SteadylineGoldEA sell");
     }
  }
//+------------------------------------------------------------------+
