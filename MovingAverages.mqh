#property strict

#ifndef MOVING_AVERAGES_MQH
#define MOVING_AVERAGES_MQH

#include "CommonUtils.mqh"

enum ENUM_MA_TYPE_SELECTION
{
   USE_EMA_ONLY,
   USE_SMA_ONLY,
   USE_BOTH_EMA_SMA
};

struct MAConfig
{
   // Daily timeframe settings
   bool   showMA50;
   bool   showMA100;
   bool   showMA200;
   bool   showMA800;
   
   // Weekly timeframe settings
   bool   showWeeklyMA50;
   bool   showWeeklyMA100;
   bool   showWeeklyMA200;
   bool   showWeeklyMA800;
   
   ENUM_MA_TYPE_SELECTION useMAType;
   
   // Colors for daily MAs
   color  colorMA50;
   color  colorMA100;
   color  colorMA200;
   color  colorMA800;
   
   // Colors for weekly MAs
   color  colorWeeklyMA50;
   color  colorWeeklyMA100;
   color  colorWeeklyMA200;
   color  colorWeeklyMA800;
   
   int    maWidth;
   ENUM_LINE_STYLE maStyle;
   
   // Optional: Weekly line style and width (if different)
   int    weeklyMaWidth;
   ENUM_LINE_STYLE weeklyMaStyle;
   
   MAConfig()
   {
      // Daily settings
      showMA50 = true;
      showMA100 = true;
      showMA200 = true;
      showMA800 = true;
      
      // Weekly settings
      showWeeklyMA50 = true;
      showWeeklyMA100 = true;
      showWeeklyMA200 = true;
      showWeeklyMA800 = true;
      
      useMAType = USE_BOTH_EMA_SMA;
      
      // Daily colors
      colorMA50 = clrRed;
      colorMA100 = clrBlue;
      colorMA200 = clrGreen;
      colorMA800 = clrPurple;
      
      // Weekly colors (using distinct colors for easy identification)
      colorWeeklyMA50 = clrOrange;
      colorWeeklyMA100 = clrMagenta;
      colorWeeklyMA200 = clrTeal;
      colorWeeklyMA800 = clrDarkSlateGray;
      
      // Line style settings
      maWidth = 2;
      maStyle = STYLE_SOLID;
      
      // Weekly line style (thicker to distinguish from daily)
      weeklyMaWidth = 3;
      weeklyMaStyle = STYLE_DASH;
   }
};

class CMovingAverages
{
private:
   MAConfig m_config;
   string   m_namePrefix;
   
   // Daily MA handles
   int      m_ema50Handle;
   int      m_ema100Handle;
   int      m_ema200Handle;
   int      m_ema800Handle;
   
   int      m_sma50Handle;
   int      m_sma100Handle;
   int      m_sma200Handle;
   int      m_sma800Handle;
   
   // Weekly MA handles
   int      m_weeklyEma50Handle;
   int      m_weeklyEma100Handle;
   int      m_weeklyEma200Handle;
   int      m_weeklyEma800Handle;
   
   int      m_weeklySma50Handle;
   int      m_weeklySma100Handle;
   int      m_weeklySma200Handle;
   int      m_weeklySma800Handle;
   
   double GetMAValue(int handle);
   void   DrawMovingAverage(int handle, int period, ENUM_TIMEFRAMES timeframe, color maColor, int width, ENUM_LINE_STYLE style, string nameSuffix);

public:
   CMovingAverages();
   ~CMovingAverages();
   
   bool Init(MAConfig &config);
   void Cleanup();
   bool UpdateMovingAverages();
   
   // Daily MA getters
   double GetEMA50Value();
   double GetEMA100Value();
   double GetEMA200Value();
   double GetEMA800Value();
   
   double GetSMA50Value();
   double GetSMA100Value();
   double GetSMA200Value();
   double GetSMA800Value();
   
   // Weekly MA getters
   double GetWeeklyEMA50Value();
   double GetWeeklyEMA100Value();
   double GetWeeklyEMA200Value();
   double GetWeeklyEMA800Value();
   
   double GetWeeklySMA50Value();
   double GetWeeklySMA100Value();
   double GetWeeklySMA200Value();
   double GetWeeklySMA800Value();
   
   MAConfig GetConfig() { return m_config; }
};

CMovingAverages::CMovingAverages()
{
   m_namePrefix = "MovingAvg";
   
   // Initialize daily handles
   m_ema50Handle = INVALID_HANDLE;
   m_ema100Handle = INVALID_HANDLE;
   m_ema200Handle = INVALID_HANDLE;
   m_ema800Handle = INVALID_HANDLE;
   
   m_sma50Handle = INVALID_HANDLE;
   m_sma100Handle = INVALID_HANDLE;
   m_sma200Handle = INVALID_HANDLE;
   m_sma800Handle = INVALID_HANDLE;
   
   // Initialize weekly handles
   m_weeklyEma50Handle = INVALID_HANDLE;
   m_weeklyEma100Handle = INVALID_HANDLE;
   m_weeklyEma200Handle = INVALID_HANDLE;
   m_weeklyEma800Handle = INVALID_HANDLE;
   
   m_weeklySma50Handle = INVALID_HANDLE;
   m_weeklySma100Handle = INVALID_HANDLE;
   m_weeklySma200Handle = INVALID_HANDLE;
   m_weeklySma800Handle = INVALID_HANDLE;
}

CMovingAverages::~CMovingAverages()
{
   Cleanup();
}

bool CMovingAverages::Init(MAConfig &config)
{
   m_config = config;
   
   // Release existing daily handles
   if(m_ema50Handle != INVALID_HANDLE) IndicatorRelease(m_ema50Handle);
   if(m_ema100Handle != INVALID_HANDLE) IndicatorRelease(m_ema100Handle);
   if(m_ema200Handle != INVALID_HANDLE) IndicatorRelease(m_ema200Handle);
   if(m_ema800Handle != INVALID_HANDLE) IndicatorRelease(m_ema800Handle);
   
   if(m_sma50Handle != INVALID_HANDLE) IndicatorRelease(m_sma50Handle);
   if(m_sma100Handle != INVALID_HANDLE) IndicatorRelease(m_sma100Handle);
   if(m_sma200Handle != INVALID_HANDLE) IndicatorRelease(m_sma200Handle);
   if(m_sma800Handle != INVALID_HANDLE) IndicatorRelease(m_sma800Handle);
   
   // Release existing weekly handles
   if(m_weeklyEma50Handle != INVALID_HANDLE) IndicatorRelease(m_weeklyEma50Handle);
   if(m_weeklyEma100Handle != INVALID_HANDLE) IndicatorRelease(m_weeklyEma100Handle);
   if(m_weeklyEma200Handle != INVALID_HANDLE) IndicatorRelease(m_weeklyEma200Handle);
   if(m_weeklyEma800Handle != INVALID_HANDLE) IndicatorRelease(m_weeklyEma800Handle);
   
   if(m_weeklySma50Handle != INVALID_HANDLE) IndicatorRelease(m_weeklySma50Handle);
   if(m_weeklySma100Handle != INVALID_HANDLE) IndicatorRelease(m_weeklySma100Handle);
   if(m_weeklySma200Handle != INVALID_HANDLE) IndicatorRelease(m_weeklySma200Handle);
   if(m_weeklySma800Handle != INVALID_HANDLE) IndicatorRelease(m_weeklySma800Handle);
   
   bool success = true;
   
   // Initialize daily EMAs
   if(m_config.useMAType == USE_EMA_ONLY || m_config.useMAType == USE_BOTH_EMA_SMA)
   {
      if(m_config.showMA50)
      {
         m_ema50Handle = iMA(_Symbol, PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE);
         if(m_ema50Handle == INVALID_HANDLE) success = false;
      }
      
      if(m_config.showMA100)
      {
         m_ema100Handle = iMA(_Symbol, PERIOD_D1, 100, 0, MODE_EMA, PRICE_CLOSE);
         if(m_ema100Handle == INVALID_HANDLE) success = false;
      }
      
      if(m_config.showMA200)
      {
         m_ema200Handle = iMA(_Symbol, PERIOD_D1, 200, 0, MODE_EMA, PRICE_CLOSE);
         if(m_ema200Handle == INVALID_HANDLE) success = false;
      }
      
      if(m_config.showMA800)
      {
         m_ema800Handle = iMA(_Symbol, PERIOD_D1, 800, 0, MODE_EMA, PRICE_CLOSE);
         if(m_ema800Handle == INVALID_HANDLE) success = false;
      }
      
      // Initialize weekly EMAs
      if(m_config.showWeeklyMA50)
      {
         m_weeklyEma50Handle = iMA(_Symbol, PERIOD_W1, 50, 0, MODE_EMA, PRICE_CLOSE);
         if(m_weeklyEma50Handle == INVALID_HANDLE) success = false;
      }
      
      if(m_config.showWeeklyMA100)
      {
         m_weeklyEma100Handle = iMA(_Symbol, PERIOD_W1, 100, 0, MODE_EMA, PRICE_CLOSE);
         if(m_weeklyEma100Handle == INVALID_HANDLE) success = false;
      }
      
      if(m_config.showWeeklyMA200)
      {
         m_weeklyEma200Handle = iMA(_Symbol, PERIOD_W1, 200, 0, MODE_EMA, PRICE_CLOSE);
         if(m_weeklyEma200Handle == INVALID_HANDLE) success = false;
      }
      
      if(m_config.showWeeklyMA800)
      {
         m_weeklyEma800Handle = iMA(_Symbol, PERIOD_W1, 800, 0, MODE_EMA, PRICE_CLOSE);
         if(m_weeklyEma800Handle == INVALID_HANDLE) success = false;
      }
   }
   
   // Initialize daily SMAs
   if(m_config.useMAType == USE_SMA_ONLY || m_config.useMAType == USE_BOTH_EMA_SMA)
   {
      if(m_config.showMA50)
      {
         m_sma50Handle = iMA(_Symbol, PERIOD_D1, 50, 0, MODE_SMA, PRICE_CLOSE);
         if(m_sma50Handle == INVALID_HANDLE) success = false;
      }
      
      if(m_config.showMA100)
      {
         m_sma100Handle = iMA(_Symbol, PERIOD_D1, 100, 0, MODE_SMA, PRICE_CLOSE);
         if(m_sma100Handle == INVALID_HANDLE) success = false;
      }
      
      if(m_config.showMA200)
      {
         m_sma200Handle = iMA(_Symbol, PERIOD_D1, 200, 0, MODE_SMA, PRICE_CLOSE);
         if(m_sma200Handle == INVALID_HANDLE) success = false;
      }
      
      if(m_config.showMA800)
      {
         m_sma800Handle = iMA(_Symbol, PERIOD_D1, 800, 0, MODE_SMA, PRICE_CLOSE);
         if(m_sma800Handle == INVALID_HANDLE) success = false;
      }
      
      // Initialize weekly SMAs
      if(m_config.showWeeklyMA50)
      {
         m_weeklySma50Handle = iMA(_Symbol, PERIOD_W1, 50, 0, MODE_SMA, PRICE_CLOSE);
         if(m_weeklySma50Handle == INVALID_HANDLE) success = false;
      }
      
      if(m_config.showWeeklyMA100)
      {
         m_weeklySma100Handle = iMA(_Symbol, PERIOD_W1, 100, 0, MODE_SMA, PRICE_CLOSE);
         if(m_weeklySma100Handle == INVALID_HANDLE) success = false;
      }
      
      if(m_config.showWeeklyMA200)
      {
         m_weeklySma200Handle = iMA(_Symbol, PERIOD_W1, 200, 0, MODE_SMA, PRICE_CLOSE);
         if(m_weeklySma200Handle == INVALID_HANDLE) success = false;
      }
      
      if(m_config.showWeeklyMA800)
      {
         m_weeklySma800Handle = iMA(_Symbol, PERIOD_W1, 800, 0, MODE_SMA, PRICE_CLOSE);
         if(m_weeklySma800Handle == INVALID_HANDLE) success = false;
      }
   }
   
   return success;
}

void CMovingAverages::Cleanup()
{
   // Release daily handles
   if(m_ema50Handle != INVALID_HANDLE) IndicatorRelease(m_ema50Handle);
   if(m_ema100Handle != INVALID_HANDLE) IndicatorRelease(m_ema100Handle);
   if(m_ema200Handle != INVALID_HANDLE) IndicatorRelease(m_ema200Handle);
   if(m_ema800Handle != INVALID_HANDLE) IndicatorRelease(m_ema800Handle);
   
   if(m_sma50Handle != INVALID_HANDLE) IndicatorRelease(m_sma50Handle);
   if(m_sma100Handle != INVALID_HANDLE) IndicatorRelease(m_sma100Handle);
   if(m_sma200Handle != INVALID_HANDLE) IndicatorRelease(m_sma200Handle);
   if(m_sma800Handle != INVALID_HANDLE) IndicatorRelease(m_sma800Handle);
   
   // Release weekly handles
   if(m_weeklyEma50Handle != INVALID_HANDLE) IndicatorRelease(m_weeklyEma50Handle);
   if(m_weeklyEma100Handle != INVALID_HANDLE) IndicatorRelease(m_weeklyEma100Handle);
   if(m_weeklyEma200Handle != INVALID_HANDLE) IndicatorRelease(m_weeklyEma200Handle);
   if(m_weeklyEma800Handle != INVALID_HANDLE) IndicatorRelease(m_weeklyEma800Handle);
   
   if(m_weeklySma50Handle != INVALID_HANDLE) IndicatorRelease(m_weeklySma50Handle);
   if(m_weeklySma100Handle != INVALID_HANDLE) IndicatorRelease(m_weeklySma100Handle);
   if(m_weeklySma200Handle != INVALID_HANDLE) IndicatorRelease(m_weeklySma200Handle);
   if(m_weeklySma800Handle != INVALID_HANDLE) IndicatorRelease(m_weeklySma800Handle);
   
   // Reset all handles to INVALID_HANDLE
   m_ema50Handle = INVALID_HANDLE;
   m_ema100Handle = INVALID_HANDLE;
   m_ema200Handle = INVALID_HANDLE;
   m_ema800Handle = INVALID_HANDLE;
   
   m_sma50Handle = INVALID_HANDLE;
   m_sma100Handle = INVALID_HANDLE;
   m_sma200Handle = INVALID_HANDLE;
   m_sma800Handle = INVALID_HANDLE;
   
   m_weeklyEma50Handle = INVALID_HANDLE;
   m_weeklyEma100Handle = INVALID_HANDLE;
   m_weeklyEma200Handle = INVALID_HANDLE;
   m_weeklyEma800Handle = INVALID_HANDLE;
   
   m_weeklySma50Handle = INVALID_HANDLE;
   m_weeklySma100Handle = INVALID_HANDLE;
   m_weeklySma200Handle = INVALID_HANDLE;
   m_weeklySma800Handle = INVALID_HANDLE;
}

// Method to draw a moving average on the chart
void CMovingAverages::DrawMovingAverage(int handle, int period, ENUM_TIMEFRAMES timeframe, color maColor, int width, ENUM_LINE_STYLE style, string nameSuffix)
{
   if(handle == INVALID_HANDLE)
      return;
      
   double maValues[];
   ArraySetAsSeries(maValues, true);
   
   if(CopyBuffer(handle, 0, 0, 1000, maValues) <= 0)
      return;
      
   string objName = m_namePrefix + "_" + nameSuffix;
   
   ObjectDelete(0, objName);
   
   // Create the moving average line
   if(ObjectCreate(0, objName, OBJ_TREND, 0, 
                  iTime(_Symbol, PERIOD_D1, 999), maValues[999], 
                  iTime(_Symbol, PERIOD_D1, 0), maValues[0]))
   {
      ObjectSetInteger(0, objName, OBJPROP_COLOR, maColor);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, style);
      ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, true);
   }
}

bool CMovingAverages::UpdateMovingAverages()
{
   static datetime lastUpdateTime = 0;
   datetime currentTime = TimeCurrent();
   
   if(currentTime - lastUpdateTime < 1 && !MQLInfoInteger(MQL_TESTER))
      return true;
      
   lastUpdateTime = currentTime;
   
   bool updated = true;
   
   // Check daily MA handles and re-initialize if needed
   if(m_config.useMAType == USE_EMA_ONLY || m_config.useMAType == USE_BOTH_EMA_SMA)
   {
      if(m_config.showMA50 && m_ema50Handle == INVALID_HANDLE)
         updated = false;
         
      if(m_config.showMA100 && m_ema100Handle == INVALID_HANDLE)
         updated = false;
         
      if(m_config.showMA200 && m_ema200Handle == INVALID_HANDLE)
         updated = false;
         
      if(m_config.showMA800 && m_ema800Handle == INVALID_HANDLE)
         updated = false;
         
      // Check weekly MA handles
      if(m_config.showWeeklyMA50 && m_weeklyEma50Handle == INVALID_HANDLE)
         updated = false;
         
      if(m_config.showWeeklyMA100 && m_weeklyEma100Handle == INVALID_HANDLE)
         updated = false;
         
      if(m_config.showWeeklyMA200 && m_weeklyEma200Handle == INVALID_HANDLE)
         updated = false;
         
      if(m_config.showWeeklyMA800 && m_weeklyEma800Handle == INVALID_HANDLE)
         updated = false;
   }
   
   if(m_config.useMAType == USE_SMA_ONLY || m_config.useMAType == USE_BOTH_EMA_SMA)
   {
      if(m_config.showMA50 && m_sma50Handle == INVALID_HANDLE)
         updated = false;
         
      if(m_config.showMA100 && m_sma100Handle == INVALID_HANDLE)
         updated = false;
         
      if(m_config.showMA200 && m_sma200Handle == INVALID_HANDLE)
         updated = false;
         
      if(m_config.showMA800 && m_sma800Handle == INVALID_HANDLE)
         updated = false;
         
      // Check weekly MA handles
      if(m_config.showWeeklyMA50 && m_weeklySma50Handle == INVALID_HANDLE)
         updated = false;
         
      if(m_config.showWeeklyMA100 && m_weeklySma100Handle == INVALID_HANDLE)
         updated = false;
         
      if(m_config.showWeeklyMA200 && m_weeklySma200Handle == INVALID_HANDLE)
         updated = false;
         
      if(m_config.showWeeklyMA800 && m_weeklySma800Handle == INVALID_HANDLE)
         updated = false;
   }
   
   if(!updated)
      Init(m_config);
   
   // Optional: Draw the moving averages on the chart
   // This can be uncommented if you want to visualize the MAs directly from this class
   /*
   // Draw daily MAs
   if(m_config.useMAType == USE_EMA_ONLY || m_config.useMAType == USE_BOTH_EMA_SMA)
   {
      if(m_config.showMA50)
         DrawMovingAverage(m_ema50Handle, 50, PERIOD_D1, m_config.colorMA50, m_config.maWidth, m_config.maStyle, "EMA50_D1");
         
      // Similar for other daily EMAs...
      
      // Draw weekly MAs
      if(m_config.showWeeklyMA50)
         DrawMovingAverage(m_weeklyEma50Handle, 50, PERIOD_W1, m_config.colorWeeklyMA50, m_config.weeklyMaWidth, m_config.weeklyMaStyle, "EMA50_W1");
         
      // Similar for other weekly EMAs...
   }
   
   // Similar for SMAs...
   */
   
   return updated;
}

double CMovingAverages::GetMAValue(int handle)
{
   if(handle == INVALID_HANDLE)
      return 0;
   
   static double buffer[];
   static datetime lastCopyTime = 0;
   static int lastHandle = 0;
   static double lastValue = 0;
   
   datetime currentTime = TimeCurrent();
   
   if(handle == lastHandle && currentTime == lastCopyTime)
      return lastValue;
      
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, 0, 0, 1, buffer) <= 0)
      return 0;
      
   lastHandle = handle;
   lastCopyTime = currentTime;
   lastValue = buffer[0];
   return lastValue;
}

// Daily MA value getters
double CMovingAverages::GetEMA50Value()
{
   return GetMAValue(m_ema50Handle);
}

double CMovingAverages::GetEMA100Value()
{
   return GetMAValue(m_ema100Handle);
}

double CMovingAverages::GetEMA200Value()
{
   return GetMAValue(m_ema200Handle);
}

double CMovingAverages::GetEMA800Value()
{
   return GetMAValue(m_ema800Handle);
}

double CMovingAverages::GetSMA50Value()
{
   return GetMAValue(m_sma50Handle);
}

double CMovingAverages::GetSMA100Value()
{
   return GetMAValue(m_sma100Handle);
}

double CMovingAverages::GetSMA200Value()
{
   return GetMAValue(m_sma200Handle);
}

double CMovingAverages::GetSMA800Value()
{
   return GetMAValue(m_sma800Handle);
}

// Weekly MA value getters
double CMovingAverages::GetWeeklyEMA50Value()
{
   return GetMAValue(m_weeklyEma50Handle);
}

double CMovingAverages::GetWeeklyEMA100Value()
{
   return GetMAValue(m_weeklyEma100Handle);
}

double CMovingAverages::GetWeeklyEMA200Value()
{
   return GetMAValue(m_weeklyEma200Handle);
}

double CMovingAverages::GetWeeklyEMA800Value()
{
   return GetMAValue(m_weeklyEma800Handle);
}

double CMovingAverages::GetWeeklySMA50Value()
{
   return GetMAValue(m_weeklySma50Handle);
}

double CMovingAverages::GetWeeklySMA100Value()
{
   return GetMAValue(m_weeklySma100Handle);
}

double CMovingAverages::GetWeeklySMA200Value()
{
   return GetMAValue(m_weeklySma200Handle);
}

double CMovingAverages::GetWeeklySMA800Value()
{
   return GetMAValue(m_weeklySma800Handle);
}

#endif