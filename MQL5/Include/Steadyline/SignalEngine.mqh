//+------------------------------------------------------------------+
//|                                                 SignalEngine.mqh |
//|          Entry/exit signal logic. Placeholder strategy:          |
//|          fast/slow EMA crossover, filtered by trend EMA.         |
//+------------------------------------------------------------------+
#property strict

enum ENUM_SIGNAL
  {
   SIGNAL_NONE = 0,
   SIGNAL_BUY  = 1,
   SIGNAL_SELL = -1
  };

class CSignalEngine
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_handle_fast;
   int               m_handle_slow;
   int               m_handle_trend;

public:
   bool Init(const string symbol, const ENUM_TIMEFRAMES timeframe,
             const int fast_period, const int slow_period, const int trend_period)
     {
      m_symbol      = symbol;
      m_timeframe   = timeframe;
      m_handle_fast  = iMA(symbol, timeframe, fast_period, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_slow  = iMA(symbol, timeframe, slow_period, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_trend = iMA(symbol, timeframe, trend_period, 0, MODE_EMA, PRICE_CLOSE);

      return (m_handle_fast != INVALID_HANDLE &&
              m_handle_slow != INVALID_HANDLE &&
              m_handle_trend != INVALID_HANDLE);
     }

   void Deinit()
     {
      if(m_handle_fast  != INVALID_HANDLE) IndicatorRelease(m_handle_fast);
      if(m_handle_slow  != INVALID_HANDLE) IndicatorRelease(m_handle_slow);
      if(m_handle_trend != INVALID_HANDLE) IndicatorRelease(m_handle_trend);
     }

   //--- evaluates the last two closed bars for a fresh crossover, filtered by trend EMA
   ENUM_SIGNAL Evaluate()
     {
      double fast[2], slow[2], trend[1];

      if(CopyBuffer(m_handle_fast, 0, 1, 2, fast) != 2)
         return SIGNAL_NONE;
      if(CopyBuffer(m_handle_slow, 0, 1, 2, slow) != 2)
         return SIGNAL_NONE;
      if(CopyBuffer(m_handle_trend, 0, 1, 1, trend) != 1)
         return SIGNAL_NONE;

      double closePrev = iClose(m_symbol, m_timeframe, 1);

      bool crossedUp   = (fast[0] <= slow[0]) && (fast[1] > slow[1]);
      bool crossedDown = (fast[0] >= slow[0]) && (fast[1] < slow[1]);

      if(crossedUp && closePrev > trend[0])
         return SIGNAL_BUY;
      if(crossedDown && closePrev < trend[0])
         return SIGNAL_SELL;

      return SIGNAL_NONE;
     }
  };
//+------------------------------------------------------------------+
