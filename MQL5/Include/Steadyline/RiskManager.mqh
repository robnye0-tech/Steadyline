//+------------------------------------------------------------------+
//|                                                 RiskManager.mqh  |
//|             Position sizing and account-level risk guards.       |
//+------------------------------------------------------------------+
#property strict

class CRiskManager
  {
private:
   string            m_symbol;
   double            m_risk_percent;
   double            m_max_daily_loss_percent;
   double            m_equity_start_of_day;
   datetime          m_current_day;

public:
   void Init(const string symbol, const double risk_percent, const double max_daily_loss_percent)
     {
      m_symbol                 = symbol;
      m_risk_percent           = risk_percent;
      m_max_daily_loss_percent = max_daily_loss_percent;
      m_equity_start_of_day    = AccountInfoDouble(ACCOUNT_EQUITY);
      m_current_day            = 0;
     }

   //--- resets the daily-loss baseline whenever the broker day rolls over
   void RefreshDailyBaseline()
     {
      MqlDateTime tm;
      TimeToStruct(TimeCurrent(), tm);
      tm.hour = 0; tm.min = 0; tm.sec = 0;
      datetime today = StructToTime(tm);

      if(today != m_current_day)
        {
         m_current_day         = today;
         m_equity_start_of_day = AccountInfoDouble(ACCOUNT_EQUITY);
        }
     }

   //--- true once today's drawdown breaches the configured limit
   bool DailyLossLimitHit()
     {
      if(m_max_daily_loss_percent <= 0.0)
         return false;

      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double lossPercent = (m_equity_start_of_day - equity) / m_equity_start_of_day * 100.0;
      return lossPercent >= m_max_daily_loss_percent;
     }

   //--- lot size such that stop-loss distance risks m_risk_percent of equity
   double LotsForStopDistance(const double stop_distance_price)
     {
      if(stop_distance_price <= 0.0)
         return 0.0;

      double equity      = AccountInfoDouble(ACCOUNT_EQUITY);
      double riskAmount  = equity * (m_risk_percent / 100.0);

      double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickValue <= 0.0 || tickSize <= 0.0)
         return 0.0;

      double valuePerPriceUnit = tickValue / tickSize;
      double lots = riskAmount / (stop_distance_price * valuePerPriceUnit);

      double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      double lotMin  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double lotMax  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);

      lots = MathFloor(lots / lotStep) * lotStep;
      lots = MathMax(lotMin, MathMin(lotMax, lots));
      return lots;
     }
  };
//+------------------------------------------------------------------+
