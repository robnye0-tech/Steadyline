//+------------------------------------------------------------------+
//|                                           ScalpSignalEngine.mqh  |
//|      Fast EMA crossover for entry timing, filtered by RSI so     |
//|      entries aren't taken into an already-exhausted move.        |
//+------------------------------------------------------------------+
#property strict

enum ENUM_SIGNAL
  {
   SIGNAL_NONE = 0,
   SIGNAL_BUY  = 1,
   SIGNAL_SELL = -1
  };

class CScalpSignalEngine
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_handle_fast;
   int               m_handle_slow;
   int               m_handle_rsi;

public:
   bool Init(const string symbol, const ENUM_TIMEFRAMES timeframe,
             const int fast_period, const int slow_period, const int rsi_period)
     {
      m_symbol     = symbol;
      m_timeframe  = timeframe;
      m_handle_fast = iMA(symbol, timeframe, fast_period, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_slow = iMA(symbol, timeframe, slow_period, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_rsi  = iRSI(symbol, timeframe, rsi_period, PRICE_CLOSE);

      return (m_handle_fast != INVALID_HANDLE &&
              m_handle_slow != INVALID_HANDLE &&
              m_handle_rsi  != INVALID_HANDLE);
     }

   void Deinit()
     {
      if(m_handle_fast != INVALID_HANDLE) IndicatorRelease(m_handle_fast);
      if(m_handle_slow != INVALID_HANDLE) IndicatorRelease(m_handle_slow);
      if(m_handle_rsi  != INVALID_HANDLE) IndicatorRelease(m_handle_rsi);
     }

   //--- fresh EMA crossover on the last closed bar, filtered by RSI so we
   //--- don't buy into an overbought spike or sell into an oversold one
   ENUM_SIGNAL Evaluate(const double rsi_buy_max, const double rsi_sell_min)
     {
      double fast[2], slow[2], rsi[1];

      if(CopyBuffer(m_handle_fast, 0, 1, 2, fast) != 2)
         return SIGNAL_NONE;
      if(CopyBuffer(m_handle_slow, 0, 1, 2, slow) != 2)
         return SIGNAL_NONE;
      if(CopyBuffer(m_handle_rsi, 0, 1, 1, rsi) != 1)
         return SIGNAL_NONE;

      bool crossedUp   = (fast[0] <= slow[0]) && (fast[1] > slow[1]);
      bool crossedDown = (fast[0] >= slow[0]) && (fast[1] < slow[1]);

      if(crossedUp && rsi[0] < rsi_buy_max)
         return SIGNAL_BUY;
      if(crossedDown && rsi[0] > rsi_sell_min)
         return SIGNAL_SELL;

      return SIGNAL_NONE;
     }
  };
//+------------------------------------------------------------------+
