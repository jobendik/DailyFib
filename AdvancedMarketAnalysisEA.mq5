#property version   "1.00"
#property strict

bool g_fibonacciRemoved = false;

#include "CommonUtils.mqh"
#include "KeyLevels.mqh"
#include "FibonacciLevels.mqh"
#include "MovingAverages.mqh"
#include "TradingZonesLogic.mqh"
#include "Trendlines.mqh"
#include "TpSlVisualizer.mqh"  // TP/SL visualization and tracking
#include "DrawdownProtection.mqh"  // Added drawdown protection

// ===== TRADING FUNCTIONALITY PARAMETERS =====

// Logging Settings
input group "Logging Settings"
enum ENUM_LOG_LEVEL
{
   LOG_LEVEL_ERROR = 0,    // Errors only
   LOG_LEVEL_WARNING = 1,  // Warnings and errors
   LOG_LEVEL_INFO = 2,     // Info, warnings, and errors
   LOG_LEVEL_DEBUG = 3     // All messages including debug
};
input ENUM_LOG_LEVEL LogLevel = LOG_LEVEL_INFO;  // Logging verbosity level

// Core Trading Settings
input group "Core Trading Settings"
input bool   EnableTrading        = true;   // Enable automated trading
input int    BaseMagicNumber      = 1;      // Base magic number (unique per symbol)
input double RiskPercent          = 0.5;   // Risk per trade (% of account)
input double RewardRatio          = 1.5;    // Reward-to-risk ratio
input double MinStopLossPips      = 30.0;   // Minimum stop loss distance (pips)
input int MarketOpenHour          = 2;       // Market open hour (24h format)
input int MarketOpenMinute        = 5;     // Market open minute
input double MaxSpreadPips        = 3.0;    // Maximum spread for order placement (pips)
input int    HistoryLookbackDays  = 3;      // Days to check for duplicate orders (1-14)
input int    MaxOpenPositions     = 3;      // Maximum simultaneous open positions (0=unlimited)
input int    MaxDailyTrades       = 5;      // Maximum new trades per day (0=unlimited)
input bool   EnableWeekendProtection = true; // Cancel pending orders before weekend
input int    WeekendCloseHour     = 21;     // Hour to cancel orders on Friday (broker time)

// Drawdown Protection Settings
input group "Drawdown Protection Settings"
input bool   EnableDrawdownProtection = true;  // Enable global drawdown protection
input double MaxDailyDrawdownPercent = 3.5;    // Maximum daily drawdown (%)
input bool   ClosePositionsOnMaxDD = true;    // Close open positions when max DD reached
input int    MaxConsecutiveLosses = 3;         // Max consecutive losses before pause (0=disabled)
input double LosingStreakPauseHours = 4.0;     // Hours to pause after losing streak

// Correlation Filter Settings
input group "Correlation Filter Settings"
input bool   EnableCorrelationFilter = false;  // Check correlation before new trades
input double CorrelationThreshold = 0.7;       // Max correlation with existing positions (0.0-1.0)
input string CorrelatedPairs = "EURUSD,GBPUSD,AUDUSD,NZDUSD;USDCHF,USDJPY,USDCAD"; // Correlated groups (semicolon separated)

// Risk Adjustment Settings
input group "Risk Adjustment Settings"
input bool   EnableRiskAdjustment = false;     // Reduce position size as DD increases
input double RiskReductionStart = 2.0;        // Start reducing risk at this DD%
input double RiskReductionSlope = 0.7;        // Reduction factor (0.1-1.0, higher = faster reduction)

// Testing Options
input group "Testing Options for DD protection"
input bool   FastTestMode = false;             // Fast performance in tester (less accurate)

// Position Management Settings
input group "Position Management Settings"
input bool   PM_EnableBreakEven   = false;    // Enable break even stop loss
input double PM_BreakEvenPips     = 15.0;     // Pips in profit before break even
input double PM_BreakEvenOffset   = 2.0;      // Break even offset in pips (+ entry)
input bool   PM_EnableTrailing    = false;    // Enable trailing stop loss
input double PM_TrailingStartPips = 20.0;     // Pips in profit before trailing starts
input double PM_TrailingDistPips  = 15.0;     // Trailing stop distance in pips
input bool   PM_EnablePartialClose = false;   // Enable partial position close
input double PM_PartialClosePercent = 50.0;   // Percentage of position to close
input double PM_PartialClosePips  = 30.0;     // Pips in profit to trigger partial close

// Order Management Settings
input group "Order Management Settings"
input double TM_CloseToEntryPips = 15.0;           // Distance to consider "close to entry" (pips)
input double TM_MovedAwayPips = 25.0;              // Distance to consider "moved away" (pips)
input double TM_AdditionalMovedAwayPips = 10.0;    // Additional distance beyond closest (pips)
input double TM_OrderTolerancePips = 2.0;          // Base tolerance for duplicate detection
input double TM_PositionToleranceMultiplier = 2.0; // Position duplicate tolerance multiplier
input double TM_HistoryToleranceMultiplier = 3.0;  // History duplicate tolerance multiplier

// Trading Zone Settings
input group "Trading Zone Settings"
input double TZ_TolerancePips      = 35.0;   // General zone tolerance (pips)
input double TZ_MATolerancePips    = 15.0;   // Moving average zone tolerance (pips)
input double TZ_MinZoneSizePips    = 30.0;   // Minimum trading zone size (pips)
input double TZ_MaxZoneSizePips    = 40.0;   // Maximum trading zone size (pips)
input double TZ_PendingOrderPips   = 2.0;    // Pending order placement distance (pips)

// Dynamic Zone Sizing Settings
input group "Dynamic Zone Sizing"
input bool   UseDynamicZoneSizing  = false;    // Use ATR for dynamic zone sizing
input int    DynamicATR_Period     = 14;      // ATR period for calculations
input double DynamicATR_MinMultiplier = 1.5;  // Multiplier for minimum zone size
input double DynamicATR_MaxMultiplier = 7.0;  // Multiplier for maximum zone size
input double DynamicATR_MinFloor    = 10.0;   // Minimum zone size floor (pips)
input double DynamicATR_MaxCeiling  = 100.0;  // Maximum zone size ceiling (pips)

// Advanced Zone Settings
input group "Advanced Zone Settings"
input double TZ_UniqueZoneTolerancePips = 15.0;    // Unique zone midpoint tolerance (pips)
input double TZ_AlreadyTradedTolerancePips = 20.0; // Already traded zone tolerance (pips)

// Fibonacci Trading Logic
input group "Fibonacci Trading Logic"
input bool   KL_EnableFibonacci      = true;    // Enable Fibonacci
input int    Fib_LookbackPeriods   = 150;    // Historical data lookback (periods)
input int    Fib_SwingStrength     = 5;      // Swing strength detection
input bool   Fib_UseMajorSwingsOnly = true;  // Use only major swings
input double Fib_MinSwingHeightPerc = 0.0005; // Minimum swing height (%)
input int    Fib_MinBarsBetweenSwings = 3;   // Minimum bars between swings
input int    Fib_MaxCandleSpan     = 100;     // Maximum candle span for pattern
input int    Fib_MinCandleSpan     = 10;      // Minimum candle span for pattern
input int    Fib_InitialSwingSearchBars = 100; // Initial swing search depth
input bool   Fib_StrictSwingDetection = true; // Use strict swing detection
input bool   UseFibForwardValidation = false;   // Use forward pattern validation
input int    FibReactionBars = 2;              // Reaction bars for validation
input double FibReactionPercentage = 0.3;      // Reaction percentage for validation

// Key Level Trading Logic
input group "Key Level Trading Logic"
input bool   KL_EnableKeyLevels    = true;    // Enable key levels
input int    KL_LookbackDays       = 365;    // Historical data lookback (days)
input int    KL_SwingWindow        = 20;     // Swing window for detecting levels
input double KL_TouchDistancePerc  = 0.0015; // Touch detection distance (%)
input double KL_StopBoxNudgePerc   = 0.10;   // Stop box nudge percentage
input double KL_MaxZoneSizePips    = 30.0;   // Maximum support/resistance zone size (pips)

// Trendline Trading Logic
input group "Trendline Trading Logic"
input bool   UseTrendlinesForTrading  = true;   // Use trendlines for confluence
input int    TL_LookbackPeriods      = 100;    // Historical data lookback (periods)
input int    TL_SwingStrength        = 5;      // Swing strength for trendlines
input double TL_TouchDistancePips    = 10.0;    // Touch detection distance (pips)
input int    TL_MinTouches           = 3;      // Minimum touches for valid line
input int    TL_MinBarsBetweenTouches = 5;     // Minimum bars between touches
input int    TL_StartBar             = 1;      // Starting bar for detection
input double TL_TouchToleranceMultiplier = 2.0; // Touch tolerance multiplier

// ===== VISUALIZATION PARAMETERS =====

// Moving Average Visualization - Updated section
input group "Moving Average Visualization"
input ENUM_MA_TYPE_SELECTION MA_UseType = USE_BOTH_EMA_SMA; // MA types to use

// Daily timeframe MAs
input bool   MA_Enable50             = false;   // Enable 50-period MA (Daily)
input bool   MA_Enable100            = true;    // Enable 100-period MA (Daily)
input bool   MA_Enable200            = true;    // Enable 200-period MA (Daily)
input bool   MA_Enable800            = true;    // Enable 800-period MA (Daily)

// Weekly timeframe MAs
input bool   MA_EnableWeekly50       = false;   // Enable 50-period MA (Weekly)
input bool   MA_EnableWeekly100      = true;    // Enable 100-period MA (Weekly)
input bool   MA_EnableWeekly200      = true;    // Enable 200-period MA (Weekly)
input bool   MA_EnableWeekly800      = true;    // Enable 800-period MA (Weekly)

// Line appearance
input int    MA_Width              = 2;      // Daily MA line width
input ENUM_LINE_STYLE MA_Style     = STYLE_SOLID; // Daily MA line style
input int    MA_WeeklyWidth        = 3;      // Weekly MA line width
input ENUM_LINE_STYLE MA_WeeklyStyle = STYLE_DASH; // Weekly MA line style

// MA Colors - Daily
input color  MA_ColorDaily50       = clrRed;       // 50-period MA color (Daily)
input color  MA_ColorDaily100      = clrBlue;      // 100-period MA color (Daily)
input color  MA_ColorDaily200      = clrGreen;     // 200-period MA color (Daily)
input color  MA_ColorDaily800      = clrPurple;    // 800-period MA color (Daily)

// MA Colors - Weekly
input color  MA_ColorWeekly50      = clrOrange;    // 50-period MA color (Weekly)
input color  MA_ColorWeekly100     = clrMagenta;   // 100-period MA color (Weekly)
input color  MA_ColorWeekly200     = clrTeal;      // 200-period MA color (Weekly)
input color  MA_ColorWeekly800     = clrDarkSlateGray; // 800-period MA color (Weekly)

// Key Level Visualization
input group "Key Level Visualization"
input color  KL_BoxColorSupport    = clrLightBlue;     // Support zone color
input color  KL_BoxColorResistance = clrSalmon;        // Resistance zone color
input color  KL_BoxColorNeutral    = clrMediumPurple;  // Neutral zone color
input int    KL_BoxTransparency    = 200;    // Zone box transparency

// Fibonacci Visualization
input group "Fibonacci Visualization"
input color  Fib_ColorBull         = clrGreen; // Bullish Fibonacci color
input color  Fib_ColorBear         = clrRed;   // Bearish Fibonacci color
input int    Fib_Width             = 3;        // Fibonacci line width
input ENUM_LINE_STYLE Fib_Style    = STYLE_SOLID; // Fibonacci line style

// Trendline Visualization
input group "Trendline Visualization"
input bool   DisplayTrendlines        = true;  // Display trendlines
input bool   TL_DisplayInvalidLines = true;   // Display invalid trendlines
input color  TL_BullTrendColor     = clrLimeGreen; // Bullish trendline color
input color  TL_BearTrendColor     = clrCrimson;   // Bearish trendline color
input color  TL_ValidForTradeColor = clrGold;      // Valid for trade color (2 touches)
input color  TL_PastThirdTouchColor = clrDimGray;   // Past 3rd touch color (invalid)
input int    TL_Width              = 2;      // Trendline width
input ENUM_LINE_STYLE TL_Style     = STYLE_SOLID; // Trendline style
input ENUM_LINE_STYLE TL_ValidForTradeStyle = STYLE_SOLID; // Valid trade style
input ENUM_LINE_STYLE TL_PastThirdTouchStyle = STYLE_DOT;  // Past valid touch style
input ENUM_LINE_STYLE TL_InvalidStyle = STYLE_DOT;  // Invalid trendline style
input int    TL_InvalidWidth       = 1;      // Invalid trendline width
input int    TL_LabelFontSize      = 8;      // Trendline label font size

// TP/SL Visualization Settings
input group "TP/SL Visualization Settings"
input bool   EnableTpSlVisualization = true;   // Show TP/SL rectangles
input color  TpRectangleColor        = clrLimeGreen;    // Active TP rectangle color
input color  SlRectangleColor        = clrRed;          // Active SL rectangle color
input color  TpFinishedColor         = clrDarkGreen;    // Finished TP rectangle color
input color  SlFinishedColor         = clrMaroon;       // Finished SL rectangle color
input color  TpCanceledColor         = clrDarkSeaGreen; // Canceled TP rectangle color
input color  SlCanceledColor         = clrLightCoral;   // Canceled SL rectangle color
input int    RectangleTransparency   = 90;     // Rectangle transparency (0-255)

datetime g_lastProcessedDay = 0;
datetime g_lastOrderExecutionDay = 0;
bool g_inBacktestMode = false;
int g_calculatedMagicNumber = 0;  // Store the calculated magic number
datetime g_lastRiskAdjustmentTime = 0;  // Track last risk adjustment time
int g_dailyTradeCount = 0;           // Track trades opened today
datetime g_lastTradeCountReset = 0;  // Last day trade count was reset
bool g_weekendOrdersCancelled = false; // Track if weekend cleanup was done

CKeyLevels*         g_keyLevels;
CFibonacciLevels*   g_fibonacci;
CMovingAverages*    g_movingAvgs;
CTradingZonesLogic* g_tradingZonesLogic;
CTrendlines*        g_trendlines;
CTpSlVisualizer*    g_tpSlVisualizer;
CDrawdownProtection* g_drawdownProtection;  // Added drawdown protection
bool g_isDrawdownLocked = false;  // Flag for drawdown lock status
double g_riskMultiplier = 1.0;    // Risk multiplier based on drawdown
int g_atrHandle = INVALID_HANDLE; // Cached ATR indicator handle for dynamic zone sizing

//+------------------------------------------------------------------+
//| Logging utility functions                                         |
//+------------------------------------------------------------------+
void LogError(string message)
{
   if(LogLevel >= LOG_LEVEL_ERROR)
      Print("[ERROR] ", message);
}

void LogWarning(string message)
{
   if(LogLevel >= LOG_LEVEL_WARNING)
      Print("[WARNING] ", message);
}

void LogInfo(string message)
{
   if(LogLevel >= LOG_LEVEL_INFO)
      Print("[INFO] ", message);
}

void LogDebug(string message)
{
   if(LogLevel >= LOG_LEVEL_DEBUG)
      Print("[DEBUG] ", message);
}

//+------------------------------------------------------------------+
//| Check if current spread is acceptable for trading                 |
//+------------------------------------------------------------------+
bool IsSpreadAcceptable()
{
   double currentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double pipValue = GetPipValue();
   double spreadInPips = currentSpread / pipValue;
   
   if(spreadInPips > MaxSpreadPips)
   {
      LogDebug("Spread too high: " + DoubleToString(spreadInPips, 1) + " pips > " + DoubleToString(MaxSpreadPips, 1) + " max");
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Calculate magic number based on symbol (with overflow protection) |
//+------------------------------------------------------------------+
int CalculateMagicNumber()
{
   string symbol = Symbol();
   uint symbolHash = 0;
   
   // Create a hash from the symbol name with better distribution
   for(int i = 0; i < StringLen(symbol); i++)
   {
      // Use a simple but effective hash algorithm
      symbolHash = (symbolHash * 31 + StringGetCharacter(symbol, i)) & 0x7FFFFFFF;
   }
   
   // Ensure hash stays within reasonable bounds and add base
   int finalMagic = BaseMagicNumber + (int)(symbolHash % 100000);
   
   return finalMagic;
}

//+------------------------------------------------------------------+
//| Calculate risk multiplier based on current drawdown               |
//+------------------------------------------------------------------+
double CalculateRiskMultiplier()
{
   // Get current drawdown percentage using real-time equity
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double currentDD = 0.0;
   
   // Calculate drawdown from equity vs balance (real-time including open P/L)
   if(balance > 0)
      currentDD = ((balance - equity) / balance) * 100.0;
   
   // Also consider the tracked drawdown from protection module
   if (EnableDrawdownProtection && g_drawdownProtection != NULL)
   {
      double trackedDD = g_drawdownProtection.GetCurrentDrawdownPercent();
      // Use the higher of the two values for safety
      currentDD = MathMax(currentDD, trackedDD);
   }
   
   // Start with full risk
   double multiplier = 1.0;
   
   if (EnableRiskAdjustment && currentDD >= RiskReductionStart)
   {
      // Calculate how much into the reduction zone we are
      double excessDD = currentDD - RiskReductionStart;
      double maxExcessDD = MaxDailyDrawdownPercent - RiskReductionStart;
      
      if (maxExcessDD <= 0) // Protection against division by zero
         maxExcessDD = 0.5;
      
      // Calculate reduction ratio (0 to 1 as DD progresses)
      double reductionRatio = MathMin(1.0, excessDD / maxExcessDD);
      
      // Apply the slope factor for customizable reduction speed
      // RiskReductionSlope of 0.7 means at max DD we're at 30% of normal risk
      multiplier = 1.0 - (reductionRatio * RiskReductionSlope);
      
      // Ensure multiplier stays between 0.1 and 1.0
      multiplier = MathMax(0.1, MathMin(1.0, multiplier));
      
      // Log the adjustment if it changed significantly
      static double lastLoggedMultiplier = 1.0;
      if(MathAbs(multiplier - lastLoggedMultiplier) > 0.05)
      {
         LogInfo("Risk adjusted: DD=" + DoubleToString(currentDD, 2) + 
                 "% -> Risk multiplier=" + DoubleToString(multiplier * 100, 0) + "%");
         lastLoggedMultiplier = multiplier;
      }
   }
   
   return multiplier;
}

//+------------------------------------------------------------------+
//| Close all open positions                                          |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   Print("Closing all positions due to max drawdown reached");
   
   CTrade trade;
   trade.SetExpertMagicNumber(g_calculatedMagicNumber);
   
   // First, cancel all pending orders
   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if (OrderGetTicket(i) > 0)
      {
         if (OrderGetInteger(ORDER_MAGIC) == g_calculatedMagicNumber)
         {
            ulong ticket = OrderGetTicket(i);
            trade.OrderDelete(ticket);
         }
      }
   }
   
   // Then close all open positions
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if (PositionGetTicket(i) > 0)
      {
         if (PositionGetInteger(POSITION_MAGIC) == g_calculatedMagicNumber)
         {
            ulong ticket = PositionGetTicket(i);
            trade.PositionClose(ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Cancel all pending orders for weekend protection                  |
//+------------------------------------------------------------------+
int CancelAllPendingOrdersForWeekend()
{
   CTrade trade;
   trade.SetExpertMagicNumber(g_calculatedMagicNumber);
   int cancelledCount = 0;
   
   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if (OrderGetTicket(i) > 0)
      {
         if (OrderGetInteger(ORDER_MAGIC) == g_calculatedMagicNumber)
         {
            ulong ticket = OrderGetTicket(i);
            if(trade.OrderDelete(ticket))
               cancelledCount++;
         }
      }
   }
   return cancelledCount;
}

//+------------------------------------------------------------------+
//| Check if new trade is allowed by daily limit                      |
//+------------------------------------------------------------------+
bool IsDailyTradeLimitReached()
{
   if(MaxDailyTrades <= 0)
      return false;  // No limit
      
   if(g_dailyTradeCount >= MaxDailyTrades)
   {
      static datetime lastWarning = 0;
      if(TimeCurrent() - lastWarning > 3600)  // Warn once per hour
      {
         LogWarning("Daily trade limit reached (" + IntegerToString(MaxDailyTrades) + "). No new trades until tomorrow.");
         lastWarning = TimeCurrent();
      }
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Increment daily trade count after successful trade                |
//+------------------------------------------------------------------+
void IncrementDailyTradeCount()
{
   g_dailyTradeCount++;
   LogInfo("Daily trade count: " + IntegerToString(g_dailyTradeCount) + "/" + IntegerToString(MaxDailyTrades));
}

//+------------------------------------------------------------------+
//| Check correlation with existing positions                         |
//+------------------------------------------------------------------+
bool IsCorrelatedPositionOpen(string symbol)
{
   if(!EnableCorrelationFilter)
      return false;
      
   // Parse correlated pairs groups
   string groups[];
   int numGroups = StringSplit(CorrelatedPairs, ';', groups);
   
   // Find which group this symbol belongs to
   string symbolGroup = "";
   for(int g = 0; g < numGroups; g++)
   {
      string pairs[];
      StringSplit(groups[g], ',', pairs);
      for(int p = 0; p < ArraySize(pairs); p++)
      {
         StringTrimLeft(pairs[p]);
         StringTrimRight(pairs[p]);
         if(pairs[p] == symbol)
         {
            symbolGroup = groups[g];
            break;
         }
      }
      if(symbolGroup != "") break;
   }
   
   if(symbolGroup == "")
      return false;  // Symbol not in any correlation group
      
   // Check if any correlated pair has open position
   string correlatedPairs[];
   StringSplit(symbolGroup, ',', correlatedPairs);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) > 0)
      {
         if(PositionGetInteger(POSITION_MAGIC) == g_calculatedMagicNumber)
         {
            string posSymbol = PositionGetString(POSITION_SYMBOL);
            if(posSymbol == symbol)
               continue;  // Skip same symbol
               
            // Check if position symbol is in same correlation group
            for(int p = 0; p < ArraySize(correlatedPairs); p++)
            {
               StringTrimLeft(correlatedPairs[p]);
               StringTrimRight(correlatedPairs[p]);
               if(correlatedPairs[p] == posSymbol)
               {
                  LogWarning("Correlation filter: Blocking " + symbol + " trade due to open " + posSymbol + " position");
                  return true;
               }
            }
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| EA initialization function                                        |
//+------------------------------------------------------------------+
int OnInit()
{
   g_inBacktestMode = MQLInfoInteger(MQL_TESTER);
   g_lastProcessedDay = 0;
   g_lastOrderExecutionDay = 0;
   
   // Calculate the symbol-specific magic number
   g_calculatedMagicNumber = CalculateMagicNumber();
   
   // Log the calculated magic number for debugging
   Print("Symbol: ", Symbol(), " - Calculated Magic Number: ", g_calculatedMagicNumber);

   if(Fib_MaxCandleSpan < 5 || Fib_MaxCandleSpan > 100)
      return INIT_PARAMETERS_INCORRECT;
   
   // Initialize Key Levels
   g_keyLevels = new CKeyLevels();
   KeyLevelConfig klConfig;
   klConfig.lookbackDays = KL_LookbackDays;
   klConfig.swingWindow = KL_SwingWindow;
   klConfig.touchDistancePerc = KL_TouchDistancePerc;
   klConfig.stopBoxNudgePerc = KL_StopBoxNudgePerc;
   klConfig.boxColorSupport = KL_BoxColorSupport;
   klConfig.boxColorResistance = KL_BoxColorResistance;
   klConfig.boxColorNeutral = KL_BoxColorNeutral;
   klConfig.boxTransparency = KL_BoxTransparency;
   klConfig.showLines = KL_EnableKeyLevels;
   klConfig.maxZoneSizePips = KL_MaxZoneSizePips;
   
   g_keyLevels.Init(klConfig);
   g_keyLevels.RecalculateZones();
   
   // Initialize Fibonacci Levels
   g_fibonacci = new CFibonacciLevels();
   FibonacciConfig fibConfig;
   fibConfig.lookbackPeriods = Fib_LookbackPeriods;
   fibConfig.swingStrength = Fib_SwingStrength;
   fibConfig.useMajorSwingsOnly = Fib_UseMajorSwingsOnly;
   fibConfig.fiboColorBull = Fib_ColorBull;
   fibConfig.fiboColorBear = Fib_ColorBear;
   fibConfig.fiboWidth = Fib_Width;
   fibConfig.fiboStyle = Fib_Style;
   fibConfig.minSwingHeightPerc = Fib_MinSwingHeightPerc;
   fibConfig.minBarsBetweenSwings = Fib_MinBarsBetweenSwings;
   fibConfig.showLabels = KL_EnableFibonacci;
   fibConfig.maxCandleSpan = Fib_MaxCandleSpan;
   fibConfig.initialSwingSearchBars = Fib_InitialSwingSearchBars;
   fibConfig.useForwardValidation = UseFibForwardValidation;
   fibConfig.minReactionBars = FibReactionBars;
   fibConfig.reactionPercentage = FibReactionPercentage;
   
   g_fibonacci.Init(fibConfig);
   
   // Initialize Moving Averages
   g_movingAvgs = new CMovingAverages();
   MAConfig maConfig;
   
   // Daily MA settings
   maConfig.showMA50 = MA_Enable50;
   maConfig.showMA100 = MA_Enable100;
   maConfig.showMA200 = MA_Enable200;
   maConfig.showMA800 = MA_Enable800;
   
   // Weekly MA settings
   maConfig.showWeeklyMA50 = MA_EnableWeekly50;
   maConfig.showWeeklyMA100 = MA_EnableWeekly100;
   maConfig.showWeeklyMA200 = MA_EnableWeekly200;
   maConfig.showWeeklyMA800 = MA_EnableWeekly800;
   
   // MA type selection
   maConfig.useMAType = MA_UseType;
   
   // Daily MA colors
   maConfig.colorMA50 = MA_ColorDaily50;
   maConfig.colorMA100 = MA_ColorDaily100;
   maConfig.colorMA200 = MA_ColorDaily200;
   maConfig.colorMA800 = MA_ColorDaily800;
   
   // Weekly MA colors
   maConfig.colorWeeklyMA50 = MA_ColorWeekly50;
   maConfig.colorWeeklyMA100 = MA_ColorWeekly100; 
   maConfig.colorWeeklyMA200 = MA_ColorWeekly200;
   maConfig.colorWeeklyMA800 = MA_ColorWeekly800;
   
   // Line styles and widths
   maConfig.maWidth = MA_Width;
   maConfig.maStyle = MA_Style;
   maConfig.weeklyMaWidth = MA_WeeklyWidth;
   maConfig.weeklyMaStyle = MA_WeeklyStyle;
   
   g_movingAvgs.Init(maConfig);
   
   // Initialize Trendlines
   g_trendlines = new CTrendlines();
   if(DisplayTrendlines)
   {
      TrendlineConfig tlConfig;
      tlConfig.lookbackPeriods = TL_LookbackPeriods;
      tlConfig.swingStrength = TL_SwingStrength;
      tlConfig.touchDistancePips = TL_TouchDistancePips;
      tlConfig.minTouches = TL_MinTouches;
      tlConfig.bullTrendColor = TL_BullTrendColor;
      tlConfig.bearTrendColor = TL_BearTrendColor;
      
      // Add new configurations
      tlConfig.validForTradeColor = TL_ValidForTradeColor;
      tlConfig.pastThirdTouchColor = TL_PastThirdTouchColor;
      tlConfig.validForTradeStyle = TL_ValidForTradeStyle;
      tlConfig.pastThirdTouchStyle = TL_PastThirdTouchStyle;
      
      // Original configurations
      tlConfig.lineWidth = TL_Width;
      tlConfig.lineStyle = TL_Style;
      tlConfig.startBar = TL_StartBar;
      tlConfig.minBarsBetweenTouches = TL_MinBarsBetweenTouches;
      tlConfig.displayInvalidLines = TL_DisplayInvalidLines;
      tlConfig.invalidLineStyle = TL_InvalidStyle;
      tlConfig.invalidLineWidth = TL_InvalidWidth;
      tlConfig.labelFontSize = TL_LabelFontSize;
      tlConfig.touchToleranceMultiplier = TL_TouchToleranceMultiplier;
      
      g_trendlines.Init(tlConfig);
   }
   else
   {
      g_trendlines.Hide();
   }
   
   // Initialize TP/SL Visualizer
   g_tpSlVisualizer = new CTpSlVisualizer();
   g_tpSlVisualizer.Init(g_calculatedMagicNumber, EnableTpSlVisualization, 
                       TpRectangleColor, SlRectangleColor, 
                       TpFinishedColor, SlFinishedColor,
                       TpCanceledColor, SlCanceledColor,
                       RectangleTransparency);

   // Calculate initial dynamic zone sizes if enabled
   double initialMinZonePips = TZ_MinZoneSizePips;
   double initialMaxZonePips = TZ_MaxZoneSizePips;
   double initialAtrPips = 0;
   
   if(UseDynamicZoneSizing)
   {
      CalculateDynamicZoneSizes(initialMinZonePips, initialMaxZonePips, initialAtrPips);
      Print("Initial dynamic zone sizes: Min=", initialMinZonePips, " Max=", initialMaxZonePips, 
            " ATR(", DynamicATR_Period, ")=", initialAtrPips, " pips");
   }

   // Initialize Trading Zones Logic
   g_tradingZonesLogic = new CTradingZonesLogic(g_fibonacci, g_keyLevels, g_movingAvgs, g_trendlines);
   g_tradingZonesLogic.Init(
      TZ_TolerancePips,
      TZ_MATolerancePips,
      initialMinZonePips,           // Use dynamic value instead of TZ_MinZoneSizePips
      initialMaxZonePips,           // Use dynamic value instead of TZ_MaxZoneSizePips
      MinStopLossPips,
      EnableTrading ? RiskPercent : 0.0,
      RewardRatio,
      g_calculatedMagicNumber,
      TZ_PendingOrderPips,
      UseTrendlinesForTrading,

      // Add position management parameters
      PM_EnableBreakEven,
      PM_BreakEvenPips,
      PM_BreakEvenOffset,
      PM_EnableTrailing,
      PM_TrailingStartPips,
      PM_TrailingDistPips,
      PM_EnablePartialClose,
      PM_PartialClosePercent,
      PM_PartialClosePips
   );
   
   // Initialize drawdown protection
   g_drawdownProtection = new CDrawdownProtection();
   if (!g_drawdownProtection.Init(MaxDailyDrawdownPercent))
   {
      Print("Failed to initialize drawdown protection");
      return INIT_FAILED;
   }
   
   // Configure losing streak protection (equity curve protection)
   if(MaxConsecutiveLosses > 0)
   {
      g_drawdownProtection.SetMaxConsecutiveLosses(MaxConsecutiveLosses);
      g_drawdownProtection.SetLosingStreakPauseHours(LosingStreakPauseHours);
      g_drawdownProtection.SetMagicNumber(g_calculatedMagicNumber);  // Only count this EA's losses
      Print("Losing streak protection enabled: Max ", MaxConsecutiveLosses, 
            " consecutive losses, ", DoubleToString(LosingStreakPauseHours, 1), "h pause");
   }
   
   // Configure fast test mode for better performance in backtesting
   if(FastTestMode && g_inBacktestMode)
   {
      // Completely disable file operations in testing
      g_drawdownProtection.DisableFileOperations(true);
      
      // Set faster update intervals
      g_drawdownProtection.SetUpdateInterval(60);  // 1 minute checks
      
      Print("Fast test mode enabled - drawdown protection simplified for speed");
   }
   
   // After initializing both g_tpSlVisualizer and g_tradingZonesLogic, add:
   g_tradingZonesLogic.SetTpSlVisualizer(g_tpSlVisualizer);
   
   // Configure trading manager settings for reliability improvements
   g_tradingZonesLogic.SetHistoryLookbackDays(HistoryLookbackDays);
   g_tradingZonesLogic.SetMaxSpreadPips(MaxSpreadPips);
   g_tradingZonesLogic.SetMaxOpenPositions(MaxOpenPositions);
   
   // Configure order management settings
   g_tradingZonesLogic.SetOrderManagementSettings(
      TM_CloseToEntryPips, TM_MovedAwayPips, TM_AdditionalMovedAwayPips,
      TM_OrderTolerancePips, TM_PositionToleranceMultiplier, TM_HistoryToleranceMultiplier);
   
   // Configure trade restriction callbacks
   if(MaxDailyTrades > 0)
      g_tradingZonesLogic.SetTradeLimitCallback(IsDailyTradeLimitReached);
   g_tradingZonesLogic.SetTradeCounterCallback(IncrementDailyTradeCount);
   if(EnableCorrelationFilter)
      g_tradingZonesLogic.SetCorrelationCallback(IsCorrelatedPositionOpen);
   
   LogInfo("EA initialized with HistoryLookback=" + IntegerToString(HistoryLookbackDays) + 
           " days, MaxSpread=" + DoubleToString(MaxSpreadPips, 1) + " pips" +
           ", MaxPositions=" + (MaxOpenPositions > 0 ? IntegerToString(MaxOpenPositions) : "unlimited") +
           ", MaxDailyTrades=" + (MaxDailyTrades > 0 ? IntegerToString(MaxDailyTrades) : "unlimited") +
           ", WeekendProtection=" + (EnableWeekendProtection ? "ON" : "OFF") +
           ", CorrelationFilter=" + (EnableCorrelationFilter ? "ON" : "OFF"));
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| EA deinitialization function                                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Never delete TP/SL visualization objects - they must stay forever
   
   if(g_keyLevels != NULL)
   {
      if(reason != REASON_CHARTCLOSE && reason != REASON_PROGRAM)
         g_keyLevels.Cleanup();
      delete g_keyLevels;
      g_keyLevels = NULL;
   }
   
   if(g_fibonacci != NULL)
   {
      if(reason != REASON_CHARTCLOSE && reason != REASON_PROGRAM)
         g_fibonacci.Cleanup();
      delete g_fibonacci;
      g_fibonacci = NULL;
   }
   
   if(g_movingAvgs != NULL)
   {
      if(reason != REASON_CHARTCLOSE && reason != REASON_PROGRAM)
         g_movingAvgs.Cleanup();
      delete g_movingAvgs;
      g_movingAvgs = NULL;
   }
   
   if(g_trendlines != NULL)
   {
      if(reason != REASON_CHARTCLOSE && reason != REASON_PROGRAM)
         g_trendlines.Cleanup();
      delete g_trendlines;
      g_trendlines = NULL;
   }
   
   if(g_tradingZonesLogic != NULL)
   {
      if(reason != REASON_CHARTCLOSE && reason != REASON_PROGRAM)
         g_tradingZonesLogic.Cleanup();
      delete g_tradingZonesLogic;
      g_tradingZonesLogic = NULL;
   }
   
   if(g_tpSlVisualizer != NULL)
   {
      // Do NOT cleanup TP/SL visualizations - they should stay forever
      delete g_tpSlVisualizer;
      g_tpSlVisualizer = NULL;
   }
   
   if(g_drawdownProtection != NULL)
   {
      delete g_drawdownProtection;
      g_drawdownProtection = NULL;
   }
   
   // Release cached ATR indicator handle
   if(g_atrHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_atrHandle);
      g_atrHandle = INVALID_HANDLE;
   }
   
   Comment("");
}

//+------------------------------------------------------------------+
//| EA tick function                                                  |
//+------------------------------------------------------------------+
void OnTick()
{
   // Only update visuals every few seconds in backtest
   static datetime lastVisualUpdate = 0;
   bool updateVisuals = !g_inBacktestMode || TimeCurrent() - lastVisualUpdate >= 5;
   
   // Process drawdown protection with less frequency in testing
   static datetime lastDrawdownCheck = 0;
   if(EnableDrawdownProtection && g_drawdownProtection != NULL && 
      (!g_inBacktestMode || TimeCurrent() - lastDrawdownCheck >= 10))
   {
      g_drawdownProtection.ProcessTick();
      lastDrawdownCheck = TimeCurrent();
      
      // Check for lockdown status change - only when drawdown is processed
      bool currentLockStatus = g_drawdownProtection.IsAccountLocked();
      if(currentLockStatus != g_isDrawdownLocked)
      {
         g_isDrawdownLocked = currentLockStatus;
         
         if(g_isDrawdownLocked)
         {
            // Just hit max drawdown limit - take action
            Print("WARNING: Maximum daily drawdown reached! New trades blocked.");
            
            // Optional: Close all open positions if enabled
            if(ClosePositionsOnMaxDD)
            {
               CloseAllPositions();
            }
         }
      }
   }
   
   // Calculate risk multiplier - less frequently in testing
   static datetime lastRiskCalc = 0;
   if(EnableRiskAdjustment && (!g_inBacktestMode || TimeCurrent() - lastRiskCalc >= 10))
   {
      g_riskMultiplier = CalculateRiskMultiplier();
      lastRiskCalc = TimeCurrent();
   }
   
   // Add visual indicator to chart - less frequently in testing
   if(updateVisuals)
   {
      string ddStatus = StringFormat("Current DD: %.2f%% of %.2f%% Max | Risk: %.0f%% | Status: %s", 
                       g_drawdownProtection != NULL ? g_drawdownProtection.GetCurrentDrawdownPercent() : 0.0,
                       MaxDailyDrawdownPercent,
                       g_riskMultiplier * 100.0,  // Show as percentage
                       g_isDrawdownLocked ? "LOCKED" : "TRADING");
      
      Comment(ddStatus);
      lastVisualUpdate = TimeCurrent();
   }

   // Stop processing if account is locked
   if(g_isDrawdownLocked && EnableDrawdownProtection)
      return;

   // For position management (break-even, trailing), we need tick-level processing
   // Only skip heavy calculations like zone detection in live mode
   static datetime lastHeavyProcess = 0;
   bool doHeavyProcessing = g_inBacktestMode || (TimeCurrent() - lastHeavyProcess >= 60);
   
   if(doHeavyProcessing)
      lastHeavyProcess = TimeCurrent();
      
   // Standard daily processing
   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   datetime currentDay = StringToTime(TimeToString(currentTime, TIME_DATE));
   
   bool isOneAM = (dt.hour == MarketOpenHour && dt.min < MarketOpenMinute);
   bool isNewDay = (currentDay > g_lastProcessedDay);
   
   // Reset daily trade count on new day
   if(currentDay > g_lastTradeCountReset)
   {
      g_dailyTradeCount = 0;
      g_lastTradeCountReset = currentDay;
      g_weekendOrdersCancelled = false;  // Reset weekend flag for new week
      if(MaxDailyTrades > 0)
         LogInfo("Daily trade count reset. Max daily trades: " + IntegerToString(MaxDailyTrades));
   }
   
   // Weekend gap protection - cancel pending orders on Friday evening
   if(EnableWeekendProtection && dt.day_of_week == 5 && dt.hour >= WeekendCloseHour && !g_weekendOrdersCancelled)
   {
      int cancelledCount = CancelAllPendingOrdersForWeekend();
      if(cancelledCount > 0)
         LogWarning("Weekend protection: Cancelled " + IntegerToString(cancelledCount) + " pending orders before weekend gap");
      g_weekendOrdersCancelled = true;
   }
   
   // Update dynamic zone sizes if enabled
   static double lastMinZonePips = 0, lastMaxZonePips = 0;
   
   if(UseDynamicZoneSizing && g_tradingZonesLogic != NULL && isNewDay)
   {
      double newMinZonePips, newMaxZonePips, atrPips;
      CalculateDynamicZoneSizes(newMinZonePips, newMaxZonePips, atrPips);
      
      // Only update if values changed significantly (>5%) or first initialization
      bool sizesChanged = lastMinZonePips == 0 || lastMaxZonePips == 0 ||
                         MathAbs(newMinZonePips - lastMinZonePips) / lastMinZonePips > 0.05 || 
                         MathAbs(newMaxZonePips - lastMaxZonePips) / lastMaxZonePips > 0.05;
      
      if(sizesChanged)
      {
         // Update the trading zones logic with new sizes
         g_tradingZonesLogic.UpdateZoneSizes(newMinZonePips, newMaxZonePips);
         
         // Store for future comparison
         lastMinZonePips = newMinZonePips;
         lastMaxZonePips = newMaxZonePips;
         
         // Log the updated values
         Print("Updated dynamic zone sizes: Min=", newMinZonePips, " Max=", newMaxZonePips, 
               " ATR(", DynamicATR_Period, ")=", atrPips, " pips");
      }
   }

   if(isNewDay)
   {
      g_keyLevels.RecalculateZones();
      g_movingAvgs.UpdateMovingAverages();
      g_fibonacci.ProcessBar(g_movingAvgs);
      g_trendlines.ProcessBar();
      
      if(EnableTrading && g_tradingZonesLogic != NULL)
         g_tradingZonesLogic.SetAllowOrderModifications(false);
      
      g_tradingZonesLogic.ProcessBar(false);
      
      g_lastProcessedDay = currentDay;
      
      ChartRedraw();
   }
   
   if(isOneAM && EnableTrading && currentDay > g_lastOrderExecutionDay)
   {
      // Check drawdown and losing streak status before executing orders
      if(EnableDrawdownProtection && g_drawdownProtection != NULL && !g_drawdownProtection.IsTradingAllowed())
      {
         Print("====================================================");
         Print("ALERT: Daily order management BLOCKED at ", TimeToString(currentTime));
         
         if(g_drawdownProtection.IsAccountLocked())
         {
            Print("Reason: Max daily drawdown reached (", 
                  DoubleToString(g_drawdownProtection.GetCurrentDrawdownPercent(), 2), "% >= ",
                  DoubleToString(g_drawdownProtection.GetMaxDrawdownPercent(), 2), "%)");
            Print("To resume trading, wait for next trading day or manually delete the lock file:");
            Print("  File location: MQL5\\Files\\DD_Lock_", AccountInfoInteger(ACCOUNT_LOGIN), ".dat");
         }
         else if(g_drawdownProtection.IsLosingStreakLocked())
         {
            Print("Reason: Losing streak protection active (",
                  g_drawdownProtection.GetConsecutiveLosses(), " consecutive losses)");
            Print("Trading will automatically resume after the cooling-off period.");
         }
         
         Print("====================================================");
         return;
      }
      
      Print("Executing daily order management at ", TimeToString(currentTime));
      Print("Drawdown status: ", DoubleToString(g_drawdownProtection != NULL ? 
            g_drawdownProtection.GetCurrentDrawdownPercent() : 0.0, 2), "%",
            ", Consecutive losses: ", (g_drawdownProtection != NULL ? 
            IntegerToString(g_drawdownProtection.GetConsecutiveLosses()) : "0"));
      
      // Update visualizer enabled state before executing orders
      if(g_tpSlVisualizer != NULL)
         g_tpSlVisualizer.SetEnabled(EnableTpSlVisualization);
         
      // Pass risk multiplier to TradingZonesLogic for position sizing
      if(EnableRiskAdjustment && g_tradingZonesLogic != NULL)
      {
         // Apply risk adjustment by modifying the risk percent
         double adjustedRiskPercent = RiskPercent * g_riskMultiplier;
         // Update the trading zones logic to use adjusted risk
         g_tradingZonesLogic.UpdateRiskSettings(adjustedRiskPercent, RewardRatio);
      }
         
      // Execute order management
      g_tradingZonesLogic.ExecuteDailyOrderManagement();
      g_lastOrderExecutionDay = currentDay;
      
      // Sync all orders with tracking for visualization - only at 1 AM
      if(g_tpSlVisualizer != NULL && EnableTpSlVisualization)
         g_tpSlVisualizer.ForceFullUpdate();
   }
   
   // Process regular TP/SL visualization updates with less frequency in testing
   static datetime lastTpSlUpdate = 0;
   if(g_tpSlVisualizer != NULL && EnableTpSlVisualization && 
      (!g_inBacktestMode || TimeCurrent() - lastTpSlUpdate >= 5))
   {
      g_tpSlVisualizer.ProcessTick();
      lastTpSlUpdate = TimeCurrent();
   }
   
   // IMPORTANT: Position management (break-even, trailing stop, partial close) 
   // should run on every tick for responsive trade management
   // This is separate from the heavy zone processing above
   if(EnableTrading && g_tradingZonesLogic != NULL && 
      (PM_EnableBreakEven || PM_EnableTrailing || PM_EnablePartialClose))
   {
      // Process open position management on every tick (or every 5 seconds in backtest)
      static datetime lastPositionMgmtTime = 0;
      if(g_inBacktestMode)
      {
         if(TimeCurrent() - lastPositionMgmtTime >= 5)
         {
            // Use ProcessBar with trading enabled to trigger position management
            g_tradingZonesLogic.SetTradingManagerCancelQueue(true);
            g_tradingZonesLogic.ProcessBar(true);  // This calls CheckOpenTrades -> ManageOpenPositions
            g_tradingZonesLogic.SetTradingManagerCancelQueue(false);
            lastPositionMgmtTime = TimeCurrent();
         }
      }
      // In live mode, position management already runs via the trading logic
   }
}

//+------------------------------------------------------------------+
//| Trade transaction handler function                                |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans, 
                       const MqlTradeRequest& request, 
                       const MqlTradeResult& result)
{
   // Forward order events to visualizer
   if(g_tpSlVisualizer != NULL && EnableTpSlVisualization)
      g_tpSlVisualizer.ProcessOrderEvent(trans, request, result);
}

//+------------------------------------------------------------------+
//| Optimization criterion function                                   |
//+------------------------------------------------------------------+
double OnTester()
{
   // Ensure visualizations are created at end of backtest
   if(g_tpSlVisualizer != NULL && EnableTpSlVisualization)
      g_tpSlVisualizer.SyncOrders();
   
   return 0.0;
}

//+------------------------------------------------------------------+
//| Calculate dynamic zone sizes based on ATR                         |
//+------------------------------------------------------------------+
void CalculateDynamicZoneSizes(double &minZonePips, double &maxZonePips, double &atrPips)
{
   // Default to input values if dynamic sizing is disabled
   if(!UseDynamicZoneSizing)
   {
      minZonePips = TZ_MinZoneSizePips;
      maxZonePips = TZ_MaxZoneSizePips;
      atrPips = 0;
      return;
   }

   // Create ATR handle if not already created (cached for performance)
   if(g_atrHandle == INVALID_HANDLE)
   {
      g_atrHandle = iATR(_Symbol, PERIOD_D1, DynamicATR_Period);
      if(g_atrHandle == INVALID_HANDLE)
      {
         LogWarning("Failed to create ATR indicator handle");
         minZonePips = TZ_MinZoneSizePips;
         maxZonePips = TZ_MaxZoneSizePips;
         atrPips = 0;
         return;
      }
   }

   // Copy ATR values using cached handle
   double atr[];
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) <= 0)
   {
      minZonePips = TZ_MinZoneSizePips;
      maxZonePips = TZ_MaxZoneSizePips;
      atrPips = 0;
      return;
   }

   // Convert ATR to pips
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pipValue;
   
   if(digits == 3 || digits == 5)
      pipValue = point * 10;
   else if(digits == 2 || digits == 4)
      pipValue = point * 100;
   else
      pipValue = point * 10;
      
   atrPips = atr[0] / pipValue;
   
   // Calculate dynamic zone sizes
   minZonePips = atrPips * DynamicATR_MinMultiplier;
   maxZonePips = atrPips * DynamicATR_MaxMultiplier;
   
   // Apply floor and ceiling
   minZonePips = MathMax(DynamicATR_MinFloor, minZonePips);
   maxZonePips = MathMin(DynamicATR_MaxCeiling, maxZonePips);
   
   // Ensure min is always less than max
   if(minZonePips >= maxZonePips)
   {
      minZonePips = maxZonePips * 0.5;
   }
}