//+------------------------------------------------------------------+
//|                                    TrendPullbackSignalEngine.mqh |
//|      A higher-timeframe EMA defines the trend; a Stochastic      |
//|      swing back out of oversold/overbought on the entry          |
//|      timeframe times pullback entries in that direction.         |
//+------------------------------------------------------------------+
#property strict

#include <Steadyline/Signal.mqh>

class CTrendPullbackSignalEngine
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_entry_timeframe;
   ENUM_TIMEFRAMES   m_trend_timeframe;
   int               m_handle_trend_ema = INVALID_HANDLE;
   int               m_handle_stoch     = INVALID_HANDLE;

public:
   bool Init(const string symbol,
             const ENUM_TIMEFRAMES entry_timeframe, const ENUM_TIMEFRAMES trend_timeframe,
             const int trend_ema_period,
             const int stoch_k, const int stoch_d, const int stoch_slowing)
     {
      m_symbol          = symbol;
      m_entry_timeframe = entry_timeframe;
      m_trend_timeframe = trend_timeframe;

      m_handle_trend_ema = iMA(symbol, trend_timeframe, trend_ema_period, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_stoch      = iStochastic(symbol, entry_timeframe, stoch_k, stoch_d, stoch_slowing,
                                         MODE_SMA, STO_LOWHIGH);

      return (m_handle_trend_ema != INVALID_HANDLE && m_handle_stoch != INVALID_HANDLE);
     }

   void Deinit()
     {
      if(m_handle_trend_ema != INVALID_HANDLE) IndicatorRelease(m_handle_trend_ema);
      if(m_handle_stoch     != INVALID_HANDLE) IndicatorRelease(m_handle_stoch);
     }

   //--- trend from the higher timeframe; entry timed by %K swinging back
   //--- out of an oversold/overbought extreme on the entry timeframe
   ENUM_SIGNAL Evaluate(const double stoch_oversold, const double stoch_overbought)
     {
      double trendEma[1];
      if(CopyBuffer(m_handle_trend_ema, 0, 1, 1, trendEma) != 1)
         return SIGNAL_NONE;

      double trendClose = iClose(m_symbol, m_trend_timeframe, 1);
      bool   trendUp    = trendClose > trendEma[0];
      bool   trendDown  = trendClose < trendEma[0];

      double k[2];
      if(CopyBuffer(m_handle_stoch, 0, 1, 2, k) != 2)
         return SIGNAL_NONE;

      bool crossedUpFromOversold     = (k[0] <= stoch_oversold)   && (k[1] > stoch_oversold);
      bool crossedDownFromOverbought = (k[0] >= stoch_overbought) && (k[1] < stoch_overbought);

      if(trendUp && crossedUpFromOversold)
         return SIGNAL_BUY;
      if(trendDown && crossedDownFromOverbought)
         return SIGNAL_SELL;

      return SIGNAL_NONE;
     }
  };
