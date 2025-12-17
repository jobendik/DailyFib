#property strict

#ifndef COMMON_UTILS_MQH
#define COMMON_UTILS_MQH

#define OBJNAME_PREFIX "AdvancedMarketAnalysis_"

color ColorBlend(color c1, color c2, int transparency)
{
   int r1 = (c1 & 0xFF);
   int g1 = ((c1 >> 8) & 0xFF);
   int b1 = ((c1 >>16) & 0xFF);

   int r2 = (c2 & 0xFF);
   int g2 = ((c2 >> 8) & 0xFF);
   int b2 = ((c2 >>16) & 0xFF);

   double blend = (double)transparency / 255.0;

   int rr = (int)(r1 * (1.0 - blend) + r2 * blend);
   int gg = (int)(g1 * (1.0 - blend) + g2 * blend);
   int bb = (int)(b1 * (1.0 - blend) + b2 * blend);  // Fixed: was using g2 instead of b2

   return((color)((bb << 16) + (gg << 8) + rr));
}

string CreateObjName(string component, string type, string suffix = "")
{
   return OBJNAME_PREFIX + component + "_" + type + (suffix != "" ? "_" + suffix : "");
}

double SnapToKeyRound(double price, double pipVal, double snapPips)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point == 0) return price;
   
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   if(digits == 5)
   {
      double roundBase = 0.0050;
      double scaledPrice = price / roundBase;
      double roundedPrice = MathRound(scaledPrice) * roundBase;
      
      double floor00 = MathFloor(price * 100) / 100.0;
      double ceiling00 = MathCeil(price * 100) / 100.0;
      double level50 = floor00 + 0.0050;
      
      double dist00Floor = MathAbs(price - floor00);
      double dist00Ceiling = MathAbs(price - ceiling00);
      double dist50 = MathAbs(price - level50);
      
      if(dist00Floor <= dist50 && dist00Floor <= dist00Ceiling)
         return floor00;
      else if(dist50 <= dist00Floor && dist50 <= dist00Ceiling)
         return level50;
      else
         return ceiling00;
   }
   else if(digits == 3)
   {
      double floor00 = MathFloor(price * 100) / 100.0;
      double level50 = floor00 + 0.50;
      double ceiling00 = floor00 + 1.0;
      
      double dist00Floor = MathAbs(price - floor00);
      double dist50 = MathAbs(price - level50);
      double dist00Ceiling = MathAbs(price - ceiling00);
      
      if(dist00Floor <= dist50 && dist00Floor <= dist00Ceiling)
         return floor00;
      else if(dist50 <= dist00Floor && dist50 <= dist00Ceiling)
         return level50;
      else
         return ceiling00;
   }
   
   return price;
}

double GetPipValue()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   string symbol = _Symbol;
   
   // Forex pairs: standard pip calculation
   if(digits == 5)           // EURUSD, GBPUSD etc (5 decimal)
      return point * 10.0;   // 1 pip = 0.0001
   else if(digits == 3)      // USDJPY, etc (3 decimal)
      return point * 10.0;   // 1 pip = 0.01
   else if(digits == 4)      // Some forex (4 decimal)
      return point * 10.0;   // 1 pip = 0.001
   else if(digits == 2)      // JPY pairs at some brokers, Gold, indices
   {
      // Gold (XAUUSD) - use 0.10 as pip (10 cents)
      if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
         return 0.10;
      // Silver (XAGUSD)
      if(StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "SILVER") >= 0)
         return 0.01;
      // Indices - use 1.0 as pip (1 point)
      if(StringFind(symbol, "US30") >= 0 || StringFind(symbol, "DJ") >= 0 ||
         StringFind(symbol, "US500") >= 0 || StringFind(symbol, "SPX") >= 0 ||
         StringFind(symbol, "NAS") >= 0 || StringFind(symbol, "NDX") >= 0 ||
         StringFind(symbol, "GER") >= 0 || StringFind(symbol, "DAX") >= 0 ||
         StringFind(symbol, "UK100") >= 0 || StringFind(symbol, "FTSE") >= 0 ||
         StringFind(symbol, "JP225") >= 0 || StringFind(symbol, "JPN") >= 0)
         return 1.0;
      // Default for 2-digit: use point * 10
      return point * 10.0;
   }
   else if(digits == 1)      // Some indices
   {
      return 1.0;            // 1 pip = 1 point
   }
   else if(digits == 0)      // Crypto, some indices
   {
      return 1.0;            // 1 pip = 1 point
   }
   
   // Fallback
   return point * 10.0;
}

string PriceToString(double price)
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return DoubleToString(price, digits);
}

#endif