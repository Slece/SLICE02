#property strict

#property description "SMC Synthetic EA - skeleton with strict demo guard"

#include <Trade/Trade.mqh>
CTrade trade;

input string  InpSymbol = "Volatility 75 Index";
input bool    InpDemoOnly = true;
input bool    InpRequireCHOCH = true;
input bool    InpRequireBOS = true;
input bool    InpUseOB = true;
input bool    InpUseFVG = true;
input bool    InpUseEngulfing = true;
input bool    InpUseRejection = true;
input double  InpRiskPercent = 5.0;
input double  InpRewardRisk = 2.5;
input int     InpMaxTradesDay = 10;
input double  InpMaxLossPercent = 25.0;
input double  InpMaxProfitPercent = 100.0;
input int     InpLondonStart = 8;
input int     InpLondonEnd = 12;
input int     InpNYStart = 13;
input int     InpNYEnd = 17;
input int     InpBrokerGMTOffset = 0;

int g_trades_today;
datetime g_day;
double g_start_equity;

int OnInit()
{
   if(InpDemoOnly && AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO)
   {
      Print("EA désactivé : compte réel interdit.");
      return(INIT_PARAMETERS_INCORRECT);
   }

   g_trades_today = 0;
   g_day = iTime(_Symbol, PERIOD_D1, 0);
   g_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);

   trade.SetAsyncMode(false);
   trade.SetDeviationInPoints(50);

   if(InpRiskPercent > 1.0)
      Print("AVERTISSEMENT : le risque demandé est supérieur à 1 %.");

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {}

void OnTick()
{
   datetime today = iTime(InpSymbol, PERIOD_D1, 0);
   if(today != g_day)
   {
      g_day = today;
      g_trades_today = 0;
      g_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   }

   if(!SymbolSelect(InpSymbol, true))
      return;

   if(!IsSessionTime())
      return;

   if(IsLimitReached())
      return;

   if(PositionsTotal() > 0)
      return;

   int bias = DetectConfirmedSMCBias(InpSymbol);
   if(bias == 1)
      TryBuy(InpSymbol);
   else if(bias == -1)
      TrySell(InpSymbol);
}

bool IsSessionTime()
{
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);

   int hour = now.hour - InpBrokerGMTOffset;
   if(hour < 0) hour += 24;
   if(hour >= 24) hour -= 24;

   return((hour >= InpLondonStart && hour < InpLondonEnd) ||
          (hour >= InpNYStart && hour < InpNYEnd));
}

bool IsLimitReached()
{
   if(g_trades_today >= InpMaxTradesDay)
      return true;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double profitPct = (equity - g_start_equity) / g_start_equity * 100.0;
   double lossPct = (g_start_equity - equity) / g_start_equity * 100.0;

   return(profitPct >= InpMaxProfitPercent || lossPct >= InpMaxLossPercent);
}

int DetectConfirmedSMCBias(string symbol)
{
   // Point d'intégration obligatoire : détecter les vrais pivots H1,
   // puis CHoCH puis BOS, avec invalidation par swing.
   // Ce squelette refuse volontairement toute pseudo-entrée.
   return 0;
}

bool ConfirmationBuy(string symbol)
{
   if(!InpUseEngulfing && !InpUseRejection)
      return true;

   double o1 = iOpen(symbol, PERIOD_M15, 1);
   double c1 = iClose(symbol, PERIOD_M15, 1);
   double o2 = iOpen(symbol, PERIOD_M15, 2);
   double c2 = iClose(symbol, PERIOD_M15, 2);

   bool engulfing = InpUseEngulfing && c1 > o1 && c1 > o2 && o1 < c2;
   bool rejection = InpUseRejection && iLow(symbol, PERIOD_M15, 1) < iLow(symbol, PERIOD_M15, 2);

   return engulfing || rejection;
}

bool ConfirmationSell(string symbol)
{
   if(!InpUseEngulfing && !InpUseRejection)
      return true;

   double o1 = iOpen(symbol, PERIOD_M15, 1);
   double c1 = iClose(symbol, PERIOD_M15, 1);
   double o2 = iOpen(symbol, PERIOD_M15, 2);
   double c2 = iClose(symbol, PERIOD_M15, 2);

   bool engulfing = InpUseEngulfing && c1 < o1 && c1 < o2 && o1 > c2;
   bool rejection = InpUseRejection && iHigh(symbol, PERIOD_M15, 1) > iHigh(symbol, PERIOD_M15, 2);

   return engulfing || rejection;
}

void TryBuy(string symbol)
{
   if(!ConfirmationBuy(symbol))
      return;

   // Les zones OB/FVG doivent provenir du moteur SMC complet.
   if(!InpUseOB && !InpUseFVG)
      return;

   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

   double sl = ask - 100 * point;
   OpenPosition(symbol, ORDER_TYPE_BUY, sl);
}

void TrySell(string symbol)
{
   if(!ConfirmationSell(symbol))
      return;

   if(!InpUseOB && !InpUseFVG)
      return;

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

   double sl = bid + 100 * point;
   OpenPosition(symbol, ORDER_TYPE_SELL, sl);
}

void OpenPosition(string symbol, ENUM_ORDER_TYPE type, double sl)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * InpRiskPercent / 100.0;

   double price = (type == ORDER_TYPE_BUY)
                  ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                  : SymbolInfoDouble(symbol, SYMBOL_BID);

   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double slDistance = MathAbs(price - sl);

   if(tickSize <= 0 || tickValue <= 0 || slDistance <= 0)
      return;

   double volume = riskMoney * tickSize / (slDistance * tickValue);
   double step = SymbolInfoGetDouble(symbol, SYMBOL_VOLUME_STEP);
   double minVolume = SymbolInfoGetDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoGetDouble(symbol, SYMBOL_VOLUME_MAX);

   volume = MathFloor(volume / step) * step;
   volume = MathMax(minVolume, MathMin(maxVolume, volume));

   double digits = (double)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   sl = NormalizeDouble(sl, (int)digits);

   double tp;
   if(type == ORDER_TYPE_BUY)
      tp = NormalizeDouble(price + (price - sl) * InpRewardRisk, (int)digits);
   else
      tp = NormalizeDouble(price - (sl - price) * InpRewardRisk, (int)digits);

   if(trade.PositionOpen(symbol, type, volume, price, sl, tp, "SMC_Synthetic"))
      g_trades_today++;
}
