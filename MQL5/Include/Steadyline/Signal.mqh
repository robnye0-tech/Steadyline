//+------------------------------------------------------------------+
//|                                                       Signal.mqh |
//|      Shared signal type, included by every signal engine.       |
//+------------------------------------------------------------------+
#property strict

#ifndef STEADYLINE_SIGNAL_MQH
#define STEADYLINE_SIGNAL_MQH

enum ENUM_SIGNAL
  {
   SIGNAL_NONE = 0,
   SIGNAL_BUY  = 1,
   SIGNAL_SELL = -1
  };

#endif
