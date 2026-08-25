//+------------------------------------------------------------------+
//|                                    MeanReversionSignalEngine.mqh |
//|      Bollinger Band mean-reversion: fade a close outside the     |
//|      band when RSI confirms an extreme, betting on reversion     |
//|      to the mean rather than continuation.                       |
//+------------------------------------------------------------------+
#property strict

#include <Steadyline/Signal.mqh>

class CMeanReversionSignalEngine
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_handle_bb  = INVALID_HANDLE;
   int               m_handle_rsi = INVALID_HANDLE;

public:
   bool Init(const string symbol, const ENUM_TIMEFRAMES timeframe,
             const int bb_period, const double bb_deviation, const int rsi_period)
     {
      m_symbol     = symbol;
      m_timeframe  = timeframe;
      m_handle_bb  = iBands(symbol, timeframe, bb_period, 0, bb_deviation, PRICE_CLOSE);
      m_handle_rsi = iRSI(symbol, timeframe, rsi_period, PRICE_CLOSE);

      return (m_handle_bb != INVALID_HANDLE && m_handle_rsi != INVALID_HANDLE);
     }

   void Deinit()
     {
      if(m_handle_bb  != INVALID_HANDLE) IndicatorRelease(m_handle_bb);
      if(m_handle_rsi != INVALID_HANDLE) IndicatorRelease(m_handle_rsi);
     }

   //--- fade a close that printed outside the bands, confirmed by an RSI extreme
   ENUM_SIGNAL Evaluate(const double rsi_oversold, const double rsi_overbought)
     {
      double upper[1], lower[1], rsi[1];

      if(CopyBuffer(m_handle_bb, 1, 1, 1, upper) != 1)   // upper band buffer
         return SIGNAL_NONE;
      if(CopyBuffer(m_handle_bb, 2, 1, 1, lower) != 1)   // lower band buffer
         return SIGNAL_NONE;
      if(CopyBuffer(m_handle_rsi, 0, 1, 1, rsi) != 1)
         return SIGNAL_NONE;

      double closePrev = iClose(m_symbol, m_timeframe, 1);

      if(closePrev <= lower[0] && rsi[0] < rsi_oversold)
         return SIGNAL_BUY;
      if(closePrev >= upper[0] && rsi[0] > rsi_overbought)
         return SIGNAL_SELL;

      return SIGNAL_NONE;
     }
  };
