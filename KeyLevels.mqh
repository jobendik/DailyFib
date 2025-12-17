#property strict

#ifndef KEY_LEVELS_MQH
#define KEY_LEVELS_MQH

#include "CommonUtils.mqh"

struct KeyLevelConfig
{
   int    lookbackDays;      
   int    swingWindow; 
   double touchDistancePerc; 
   double stopBoxNudgePerc;  
   color  boxColorSupport;   
   color  boxColorResistance;
   color  boxColorNeutral;   
   int    boxTransparency;   
   bool   showLines;
   double maxZoneSizePips;      
   
   KeyLevelConfig()
   {
      lookbackDays = 365;
      swingWindow = 20;
      touchDistancePerc = 0.0015;
      stopBoxNudgePerc = 0.25;
      boxColorSupport = clrGreen;
      boxColorResistance = clrRed;
      boxColorNeutral = clrMediumPurple;
      boxTransparency = 70;
      showLines = true;
      maxZoneSizePips = 50.0;
   }
};

struct FoundLevel
{
   double   price;
   bool     isRes;
   int      barIndex;
};

class CKeyLevels
{
private:
   KeyLevelConfig m_config;
   string   m_namePrefix;
   datetime m_lastD1BarTime;
   int      m_countSupportZones;
   int      m_countResistanceZones;

   bool FindCleanReaction(double level, bool isRes, double &highArr[], double &lowArr[],
                         datetime &timeArr[], int barsCount, double touchDist,
                         int &foundIndex, double &wickEdge);
                         
   double ShiftLevelForMaxTouches(double basePrice, bool isRes, double &highArr[], double &lowArr[],
                               int barsCount, double touchDist);
                               
   int CountTouches(double level, double &highArr[], double &lowArr[],
                    int barsCount, double touchDist, bool isRes);
                    
   void RemoveDuplicates(FoundLevel &levels[], int &arrSize, double tolerance);
   
   void DrawKeyLevelZone(int zoneIndex, bool isRes, double levelPrice, 
                        double zoneHigh, double zoneLow, datetime leftTime, datetime rightTime);

public:
   CKeyLevels();
   ~CKeyLevels();
   
   bool Init(KeyLevelConfig &config);
   void Cleanup();
   bool RecalculateZones();
   void SetConfig(KeyLevelConfig &config);
   bool IsNewDailyBar();
   void Show();
   void Hide();
   void SetVisible(bool visible);
};

CKeyLevels::CKeyLevels()
{
   m_namePrefix = "KeyLevels";
   m_lastD1BarTime = 0;
   m_countSupportZones = 0;
   m_countResistanceZones = 0;
}

CKeyLevels::~CKeyLevels()
{
   Cleanup();
}

bool CKeyLevels::Init(KeyLevelConfig &config)
{
   m_config = config;
   
   if(Bars(_Symbol, PERIOD_D1) < m_config.lookbackDays)
      return false;
   
   datetime tArr[1];
   if(CopyTime(_Symbol, PERIOD_D1, 0, 1, tArr) > 0)
      m_lastD1BarTime = tArr[0];
   
   RecalculateZones();
   
   return true;
}

void CKeyLevels::Cleanup()
{
   ObjectsDeleteAll(0, CreateObjName(m_namePrefix, ""));
}

bool CKeyLevels::IsNewDailyBar()
{
   datetime tArr[1];
   if(CopyTime(_Symbol, PERIOD_D1, 0, 1, tArr) > 0)
   {
      if(tArr[0] > m_lastD1BarTime)
      {
         m_lastD1BarTime = tArr[0];
         return true;
      }
   }
   return false;
}

void CKeyLevels::SetConfig(KeyLevelConfig &config)
{
   m_config = config;
}

bool CKeyLevels::FindCleanReaction(double level, bool isRes,
                     double &highArr[], double &lowArr[],
                     datetime &timeArr[], int barsCount, double touchDist,
                     int &foundIndex, double &wickEdge)
{
   int maxCheck = MathMin(barsCount - 1, 200);

   foundIndex = -1;
   wickEdge   = level;

   for(int i=0; i<=maxCheck; i++)
   {
      if(isRes)
      {
         if(MathAbs(highArr[i] - level) <= (touchDist * 3.0))
         {
            if(lowArr[i] > (level + touchDist))
               continue;
            wickEdge   = highArr[i];
            foundIndex = i;
            return(true);
         }
      }
      else
      {
         if(MathAbs(lowArr[i] - level) <= (touchDist * 3.0))
         {
            if(highArr[i] < (level - touchDist))
               continue;
            wickEdge   = lowArr[i];
            foundIndex = i;
            return(true);
         }
      }
   }
   return(false);
}

double CKeyLevels::ShiftLevelForMaxTouches(double basePrice, bool isRes,
                           double &highArr[], double &lowArr[],
                           int barsCount, double touchDist)
{
   double bestPrice = basePrice;
   int    bestCount = 0;
   int    steps     = 7;
   double stepSize  = touchDist * 0.5;

   for(int s = -steps; s <= steps; s++)
   {
      double testPrice = basePrice + (s * stepSize);
      int    c = CountTouches(testPrice, highArr, lowArr, barsCount, touchDist, isRes);
      if(c > bestCount)
      {
         bestCount  = c;
         bestPrice  = testPrice;
      }
   }
   return(bestPrice);
}

int CKeyLevels::CountTouches(double level,
                double &highArr[], double &lowArr[],
                int barsCount, double touchDist, bool isRes)
{
   int touches   = 0;
   int lastTouch = -10;

   for(int i = 0; i < barsCount; i++)
   {
      if(isRes)
      {
         if(MathAbs(highArr[i] - level) <= touchDist)
         {
            if(i - lastTouch > 2)
            {
               touches++;
               lastTouch = i;
            }
         }
      }
      else
      {
         if(MathAbs(lowArr[i] - level) <= touchDist)
         {
            if(i - lastTouch > 2)
            {
               touches++;
               lastTouch = i;
            }
         }
      }
   }
   return(touches);
}

void CKeyLevels::RemoveDuplicates(FoundLevel &levels[], int &arrSize, double tolerance)
{
   for(int i = 0; i < arrSize - 1; i++)
   {
      for(int j = i + 1; j < arrSize; j++)
      {
         if(levels[i].isRes == levels[j].isRes)
         {
            if(MathAbs(levels[i].price - levels[j].price) < (tolerance * 2.0))
            {
               for(int k = j; k < arrSize - 1; k++)
               {
                  levels[k] = levels[k + 1];
               }
               arrSize--;
               j--;
            }
         }
      }
   }
}

void CKeyLevels::DrawKeyLevelZone(int zoneIndex, bool isRes, double levelPrice, 
                    double zoneHigh, double zoneLow, datetime leftTime, datetime rightTime)
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   color boxClr = m_config.boxColorNeutral;
   
   if(levelPrice > currentPrice)
   {
      boxClr = m_config.boxColorResistance;
   }
   else if(levelPrice < currentPrice)
   {
      boxClr = m_config.boxColorSupport;
   }

   string boxName = CreateObjName(m_namePrefix, "Zone", (isRes?"Res":"Sup") + "_"
                + DoubleToString(levelPrice, _Digits) + "_" + IntegerToString(zoneIndex));

   ObjectCreate(0, boxName, OBJ_RECTANGLE, 0,
              leftTime, zoneHigh,
              rightTime, zoneLow);
              
   ObjectSetInteger(0, boxName, OBJPROP_COLOR, boxClr);
   ObjectSetInteger(0, boxName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, boxName, OBJPROP_FILL, true);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, true);
   ObjectSetInteger(0, boxName, OBJPROP_ZORDER, 0);
   ObjectSetInteger(0, boxName, OBJPROP_BGCOLOR,
                  ColorBlend(boxClr, clrWhite, m_config.boxTransparency));
   ObjectSetString(0, boxName, OBJPROP_TOOLTIP,
                 (isRes?"Resistance":"Support")+" near "
                 + DoubleToString(levelPrice, _Digits));

   if(m_config.showLines)
   {
      string lineName = CreateObjName(m_namePrefix, "Line", (isRes?"Res":"Sup") + "_"
                    + DoubleToString(levelPrice, _Digits) + "_" + IntegerToString(zoneIndex));
                    
      ObjectCreate(0, lineName, OBJ_HLINE, 0, TimeCurrent(), levelPrice);
      
      if(levelPrice > currentPrice)
      {
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, m_config.boxColorResistance);
      }
      else if(levelPrice < currentPrice)
      {
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, m_config.boxColorSupport);
      }
      else
      {
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, m_config.boxColorNeutral);
      }
        
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
   }
}

bool CKeyLevels::RecalculateZones()
{
   ObjectsDeleteAll(0, CreateObjName(m_namePrefix, ""));

   m_countSupportZones = 0;
   m_countResistanceZones = 0;

   double   highD1[], lowD1[];
   datetime timeD1[];
   int copiedH = CopyHigh(_Symbol, PERIOD_D1, 0, m_config.lookbackDays, highD1);
   int copiedL = CopyLow(_Symbol, PERIOD_D1, 0, m_config.lookbackDays, lowD1);
   int copiedT = CopyTime(_Symbol, PERIOD_D1, 0, m_config.lookbackDays, timeD1);

   if(copiedH < 1 || copiedL < 1 || copiedT < 1)
      return false;

   ArraySetAsSeries(highD1, true);
   ArraySetAsSeries(lowD1,  true);
   ArraySetAsSeries(timeD1, true);

   double avgPrice = 0.0;
   int    barsCount = MathMin(copiedH, MathMin(copiedL, copiedT));
   for(int i = 0; i < barsCount; i++)
   {
      avgPrice += (highD1[i] + lowD1[i]) * 0.5;
   }
   avgPrice /= (double)barsCount;

   double touchDist = avgPrice * m_config.touchDistancePerc;

   FoundLevel majorLevels[];
   ArrayResize(majorLevels, 0);

   for(int bar = m_config.swingWindow; bar < barsCount - m_config.swingWindow; bar++)
   {
      bool isSwingHigh = true;
      for(int w = 1; w <= m_config.swingWindow; w++)
      {
         if(highD1[bar] <= highD1[bar - w] || highD1[bar] <= highD1[bar + w])
         {
            isSwingHigh = false;
            break;
         }
      }
      if(isSwingHigh)
      {
         int sz = ArraySize(majorLevels);
         ArrayResize(majorLevels, sz+1);
         majorLevels[sz].price    = highD1[bar];
         majorLevels[sz].isRes    = true;
         majorLevels[sz].barIndex = bar;
      }

      bool isSwingLow = true;
      for(int w = 1; w <= m_config.swingWindow; w++)
      {
         if(lowD1[bar] >= lowD1[bar - w] || lowD1[bar] >= lowD1[bar + w])
         {
            isSwingLow = false;
            break;
         }
      }
      if(isSwingLow)
      {
         int sz = ArraySize(majorLevels);
         ArrayResize(majorLevels, sz+1);
         majorLevels[sz].price    = lowD1[bar];
         majorLevels[sz].isRes    = false;
         majorLevels[sz].barIndex = bar;
      }
   }

   if(ArraySize(majorLevels) < 1)
      return false;

   for(int i = 0; i < ArraySize(majorLevels); i++)
   {
      majorLevels[i].price = ShiftLevelForMaxTouches(majorLevels[i].price,
                                               majorLevels[i].isRes,
                                               highD1, lowD1,
                                               barsCount, touchDist);
   }

   double pipVal = GetPipValue();
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   for(int i = 0; i < ArraySize(majorLevels); i++)
   {
      if(digits == 5)
      {
         double price = majorLevels[i].price;
         double floor00 = MathFloor(price * 100) / 100.0;
         double ceiling00 = MathCeil(price * 100) / 100.0;
         double level50 = floor00 + 0.0050;
         
         double dist00Floor = MathAbs(price - floor00);
         double dist00Ceiling = MathAbs(price - ceiling00);
         double dist50 = MathAbs(price - level50);
         
         if(dist00Floor <= dist50 && dist00Floor <= dist00Ceiling)
            majorLevels[i].price = floor00;
         else if(dist50 <= dist00Floor && dist50 <= dist00Ceiling)
            majorLevels[i].price = level50;
         else
            majorLevels[i].price = ceiling00;
      }
      else if(digits == 3)
      {
         double price = majorLevels[i].price;
         double floor00 = MathFloor(price);
         double level50 = floor00 + 0.50;
         double ceiling00 = floor00 + 1.0;
         
         double dist00Floor = MathAbs(price - floor00);
         double dist50 = MathAbs(price - level50);
         double dist00Ceiling = MathAbs(price - ceiling00);
         
         if(dist00Floor <= dist50 && dist00Floor <= dist00Ceiling)
            majorLevels[i].price = floor00;
         else if(dist50 <= dist00Floor && dist50 <= dist00Ceiling)
            majorLevels[i].price = level50;
         else
            majorLevels[i].price = ceiling00;
      }
      else
      {
         double price = majorLevels[i].price;
         double floor00 = MathFloor(price);
         double level50 = floor00 + 0.50;
         double ceiling00 = floor00 + 1.0;
         
         double dist00Floor = MathAbs(price - floor00);
         double dist50 = MathAbs(price - level50);
         double dist00Ceiling = MathAbs(price - ceiling00);
         
         if(dist00Floor <= dist50 && dist00Floor <= dist00Ceiling)
            majorLevels[i].price = floor00;
         else if(dist50 <= dist00Floor && dist50 <= dist00Ceiling)
            majorLevels[i].price = level50;
         else
            majorLevels[i].price = ceiling00;
      }
   }

   int lvlCount = ArraySize(majorLevels);
   RemoveDuplicates(majorLevels, lvlCount, touchDist);
   ArrayResize(majorLevels, lvlCount);

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   for(int i = 0; i < lvlCount; i++)
   {
      double theLevel = majorLevels[i].price;
      bool   isRes    = majorLevels[i].isRes;

      int    foundIdx  = -1;
      double wickEdge  = theLevel;
      bool   foundClean= FindCleanReaction(theLevel, isRes,
                                        highD1, lowD1,
                                        timeD1, barsCount,
                                        touchDist,
                                        foundIdx, wickEdge);

      double zoneHigh, zoneLow;
      if(isRes)
      {
         zoneLow  = theLevel;
         zoneHigh = (foundClean ? wickEdge : (theLevel + touchDist));
      }
      else
      {
         zoneHigh = theLevel;
         zoneLow  = (foundClean ? wickEdge : (theLevel - touchDist));
      }

      double zoneWidth = zoneHigh - zoneLow;
      if(zoneWidth < 0.0)
      {
         double tmp  = zoneLow;
         zoneLow     = zoneHigh;
         zoneHigh    = tmp;
         zoneWidth   = zoneHigh - zoneLow;
      }

      double maxZoneWidth = m_config.maxZoneSizePips * pipVal;
      if(zoneWidth > maxZoneWidth)
      {
         double midPoint = theLevel;
         double halfMaxSize = maxZoneWidth / 2.0;
         
         if(isRes)
         {
            zoneLow = theLevel;
            zoneHigh = theLevel + halfMaxSize;
         }
         else
         {
            zoneHigh = theLevel;
            zoneLow = theLevel - halfMaxSize;
         }
         zoneWidth = maxZoneWidth;
      }

      double smallNudge = m_config.stopBoxNudgePerc * zoneWidth;
      if(isRes && theLevel > currentPrice)
      {
         zoneLow -= smallNudge;
         m_countResistanceZones++;
      }
      else if(!isRes && theLevel < currentPrice)
      {
         zoneHigh += smallNudge;
         m_countSupportZones++;
      }

      if(zoneLow > zoneHigh)
      {
         double tmp = zoneLow;
         zoneLow    = zoneHigh;
         zoneHigh   = tmp;
      }

      datetime leftTime = (foundIdx >= 0) ? timeD1[foundIdx] : timeD1[barsCount - 1];
      datetime rightTime= TimeCurrent();

      DrawKeyLevelZone(i, isRes, theLevel, zoneHigh, zoneLow, leftTime, rightTime);
   }

   ChartRedraw(0);
   return true;
}

void CKeyLevels::Show()
{
   SetVisible(true);
}

void CKeyLevels::Hide()
{
   SetVisible(false);
}

void CKeyLevels::SetVisible(bool visible)
{
   int totalObjects = ObjectsTotal(0, 0, -1);
   
   for(int i = 0; i < totalObjects; i++)
   {
      string name = ObjectName(0, i);
      
      if(StringFind(name, CreateObjName(m_namePrefix, "")) >= 0)
      {
         if(visible)
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
         else
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      }
   }
   
   ChartRedraw();
}

#endif