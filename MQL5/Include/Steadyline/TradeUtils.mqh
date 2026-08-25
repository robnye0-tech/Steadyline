//+------------------------------------------------------------------+
//|                                                   TradeUtils.mqh |
//|                       Thin wrapper around CTrade for market      |
//|                       orders with SL/TP, scoped to one symbol.   |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>

class CTradeUtils
  {
private:
   CTrade            m_trade;
   string            m_symbol;
   ulong             m_magic;

public:
   void Init(const string symbol, const ulong magic, const ulong deviation_points)
     {
      m_symbol = symbol;
      m_magic  = magic;
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints(deviation_points);
      m_trade.SetTypeFillingBySymbol(symbol);
     }

   bool HasOpenPosition() const
     {
      return PositionSelect(m_symbol);
     }

   long PositionDirection() const
     {
      if(!PositionSelect(m_symbol))
         return 0;
      return (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
     }

   bool OpenBuy(const double lots, const double sl, const double tp, const string comment)
     {
      return m_trade.Buy(lots, m_symbol, 0.0, sl, tp, comment);
     }

   bool OpenSell(const double lots, const double sl, const double tp, const string comment)
     {
      return m_trade.Sell(lots, m_symbol, 0.0, sl, tp, comment);
     }

   bool CloseAll()
     {
      if(!PositionSelect(m_symbol))
         return true;
      return m_trade.PositionClose(m_symbol);
     }
  };
//+------------------------------------------------------------------+
