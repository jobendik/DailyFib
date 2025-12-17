#property strict

#ifndef DRAWDOWN_PROTECTION_MQH
#define DRAWDOWN_PROTECTION_MQH

#include "CommonUtils.mqh"

class CDrawdownProtection
{
private:
   double   m_maxDailyDrawdownPercent;  // Maximum allowed daily drawdown percentage
   double   m_accountStartBalance;      // Starting balance reference for the day
   double   m_accountStartEquity;       // Starting equity reference for the day
   double   m_maxDrawdownAmount;        // Calculated maximum drawdown amount in account currency
   double   m_dailyHighEquity;          // Highest equity reached today
   double   m_dailyLowEquity;           // Lowest equity reached today
   double   m_currentDrawdownPercent;   // Current drawdown percentage
   datetime m_lastDayChecked;           // Last day we checked for reset
   bool     m_isLocked;                 // Flag to indicate if trading is locked due to DD
   bool     m_isTesting;                // Flag for backtest mode
   string   m_lockFilename;             // Filename for storing lock status between instances
   
   // Performance optimization variables
   datetime m_lastFileCheckTime;        // Last time file was checked
   int      m_fileCheckInterval;        // How often to check file (seconds)
   bool     m_disableFileOps;           // Disable file operations in testing
   datetime m_lastProcessTime;          // Last time ProcessTick was fully executed
   
   // Equity curve protection / Losing streak detection
   int      m_consecutiveLosses;        // Current consecutive losing trades
   int      m_maxConsecutiveLosses;     // Max allowed consecutive losses before pause
   bool     m_losingStreakLocked;       // Flag for losing streak pause
   datetime m_lastTradeCheckTime;       // Last time we checked trade history
   int      m_lastHistoryDealsTotal;    // Cached history deals count
   double   m_losingStreakPauseHours;   // Hours to pause after losing streak
   datetime m_losingStreakLockTime;     // When the losing streak lock started
   int      m_magicNumber;              // Magic number to filter trades (0 = all trades)
   
   bool     ResetDailyValues();         // Reset daily tracking on a new day
   bool     UpdateDrawdownStatus();      // Update current drawdown status
   string   GetGlobalLockFilename();     // Get filename for global lock file
   void     UpdateLosingStreak();        // Check for consecutive losses

   // Unified format for lockfiles
   string   FormatLockData(bool isLocked, datetime lockTime, double ddPercent);
   bool     ParseLockData(string data, bool &isLocked, datetime &lockTime, double &ddPercent);
   void     WriteLockData(bool isLocked, datetime lockTime, double ddPercent);
   bool     ReadLockData(bool &isLocked, datetime &lockTime, double &ddPercent);
   
public:
   CDrawdownProtection();
   ~CDrawdownProtection();
   
   // Initialization with desired max drawdown percent
   bool Init(double maxDailyDrawdownPercent = 5.0);
   
   // Process regular updates (call on each tick)
   bool ProcessTick();
   
   // Check if account is currently locked from trading
   bool IsAccountLocked() const { return m_isLocked; }
   
   // Get current drawdown percentage
   double GetCurrentDrawdownPercent() const { return m_currentDrawdownPercent; }
   
   // Get max allowed drawdown percentage 
   double GetMaxDrawdownPercent() const { return m_maxDailyDrawdownPercent; }
   
   // Manual methods to override lock status (emergency use only)
   bool LockAccount();
   bool UnlockAccount();
   
   // Get status details as a string
   string GetStatusText();
   
   // Performance optimization methods
   void DisableFileOperations(bool disable) { m_disableFileOps = disable; }
   void SetUpdateInterval(int seconds) { m_fileCheckInterval = seconds; }
   
   // Losing streak / Equity curve protection
   void SetMaxConsecutiveLosses(int maxLosses) { m_maxConsecutiveLosses = MathMax(1, maxLosses); }
   void SetLosingStreakPauseHours(double hours) { m_losingStreakPauseHours = MathMax(0.5, hours); }
   void SetMagicNumber(int magicNumber) { m_magicNumber = magicNumber; }  // Filter trades by magic number
   bool IsLosingStreakLocked() const { return m_losingStreakLocked; }
   int  GetConsecutiveLosses() const { return m_consecutiveLosses; }
   bool IsTradingAllowed() const { return !m_isLocked && !m_losingStreakLocked; }
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CDrawdownProtection::CDrawdownProtection()
{
   m_maxDailyDrawdownPercent = 5.0;  // Default to 5%
   m_accountStartBalance = 0.0;
   m_accountStartEquity = 0.0;
   m_maxDrawdownAmount = 0.0;
   m_dailyHighEquity = 0.0;
   m_dailyLowEquity = 0.0;
   m_currentDrawdownPercent = 0.0;
   m_lastDayChecked = 0;
   m_isLocked = false;
   m_isTesting = MQLInfoInteger(MQL_TESTER);
   m_lockFilename = GetGlobalLockFilename();
   
   // Initialize performance variables
   m_lastFileCheckTime = 0;
   m_fileCheckInterval = m_isTesting ? 300 : 30; // 5 min in tester, 30 sec live
   m_disableFileOps = m_isTesting; // Disable file ops in testing by default
   m_lastProcessTime = 0;
   
   // Initialize losing streak protection
   m_consecutiveLosses = 0;
   m_maxConsecutiveLosses = 3;           // Default: pause after 3 consecutive losses
   m_losingStreakLocked = false;
   m_lastTradeCheckTime = 0;
   m_lastHistoryDealsTotal = 0;
   m_losingStreakPauseHours = 4.0;       // Default: 4 hour pause
   m_losingStreakLockTime = 0;
   m_magicNumber = 0;                    // Default: check all trades (0 = no filter)
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CDrawdownProtection::~CDrawdownProtection()
{
   // Nothing to clean up
}

//+------------------------------------------------------------------+
//| Initialize protection with maximum daily drawdown percentage      |
//+------------------------------------------------------------------+
bool CDrawdownProtection::Init(double maxDailyDrawdownPercent = 5.0)
{
   m_maxDailyDrawdownPercent = maxDailyDrawdownPercent;
   m_isTesting = MQLInfoInteger(MQL_TESTER);
   
   // Performance optimizations
   m_lastFileCheckTime = 0;
   m_fileCheckInterval = m_isTesting ? 300 : 30; // 5 min in tester, 30 sec live
   m_disableFileOps = m_isTesting; // Disable file ops in testing by default
   
   // Load lock state from file if not in testing mode
   if(!m_isTesting && !m_disableFileOps)
   {
      bool savedLock = false;
      datetime lockTime = 0;
      double ddPercent = 0.0;
      
      if(ReadLockData(savedLock, lockTime, ddPercent))
      {
         // Check if lock should still be active (from same day)
         MqlDateTime dt, lockDt;
         TimeToStruct(TimeCurrent(), dt);
         TimeToStruct(lockTime, lockDt);
         
         if(savedLock && dt.day == lockDt.day && dt.mon == lockDt.mon && dt.year == lockDt.year)
         {
            m_isLocked = true;
            m_currentDrawdownPercent = ddPercent;
            Print("Drawdown protection: Account already locked from earlier session with DD: ", 
                  DoubleToString(ddPercent, 2), "%");
         }
      }
   }
   
   // Initialize daily values
   ResetDailyValues();
   
   return true;
}

//+------------------------------------------------------------------+
//| Format lock data for storage                                      |
//+------------------------------------------------------------------+
string CDrawdownProtection::FormatLockData(bool isLocked, datetime lockTime, double ddPercent)
{
   return StringFormat("%d|%d|%.2f", isLocked ? 1 : 0, lockTime, ddPercent);
}

//+------------------------------------------------------------------+
//| Parse lock data from storage                                      |
//+------------------------------------------------------------------+
bool CDrawdownProtection::ParseLockData(string data, bool &isLocked, datetime &lockTime, double &ddPercent)
{
   string parts[];
   int count = StringSplit(data, '|', parts);
   
   if(count != 3)
      return false;
      
   isLocked = (StringToInteger(parts[0]) == 1);
   lockTime = (datetime)StringToInteger(parts[1]);
   ddPercent = StringToDouble(parts[2]);
   
   return true;
}

//+------------------------------------------------------------------+
//| Write lock data to file                                           |
//+------------------------------------------------------------------+
void CDrawdownProtection::WriteLockData(bool isLocked, datetime lockTime, double ddPercent)
{
   // Skip in testing mode or if disabled
   if(m_disableFileOps)
      return;
      
   string data = FormatLockData(isLocked, lockTime, ddPercent);
   
   // Only write if lock status changed or significant time passed
   static datetime lastWriteTime = 0;
   static bool lastLockStatus = false;
   
   if(lastLockStatus != isLocked || TimeCurrent() - lastWriteTime > m_fileCheckInterval)
   {
      int handle = FileOpen(m_lockFilename, FILE_WRITE|FILE_TXT);
      if(handle != INVALID_HANDLE)
      {
         FileWriteString(handle, data);
         FileClose(handle);
         lastWriteTime = TimeCurrent();
         lastLockStatus = isLocked;
      }
      else
      {
         Print("Drawdown protection: Error writing lock file, error code: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Read lock data from file                                          |
//+------------------------------------------------------------------+
bool CDrawdownProtection::ReadLockData(bool &isLocked, datetime &lockTime, double &ddPercent)
{
   // Return default values in testing mode or if too soon to check again
   if(m_disableFileOps || (TimeCurrent() - m_lastFileCheckTime < m_fileCheckInterval))
   {
      isLocked = m_isLocked;
      lockTime = 0;
      ddPercent = m_currentDrawdownPercent;
      return true;
   }
   
   m_lastFileCheckTime = TimeCurrent();
   
   int handle = FileOpen(m_lockFilename, FILE_READ|FILE_TXT);
   if(handle != INVALID_HANDLE)
   {
      string data = FileReadString(handle);
      FileClose(handle);
      
      return ParseLockData(data, isLocked, lockTime, ddPercent);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get global lock filename (shared across all chart instances)      |
//+------------------------------------------------------------------+
string CDrawdownProtection::GetGlobalLockFilename()
{
   // Create a unique filename based on account number and date
   int account = (int)AccountInfoInteger(ACCOUNT_LOGIN);
   return StringFormat("DD_Lock_%d.dat", account);
}

//+------------------------------------------------------------------+
//| Reset daily tracking values                                       |
//+------------------------------------------------------------------+
bool CDrawdownProtection::ResetDailyValues()
{
   datetime current = TimeCurrent();
   
   if(m_lastDayChecked == 0)
   {
      // First time initialization
      m_lastDayChecked = current;
      
      // Initialize with current values
      m_accountStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_accountStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_dailyHighEquity = m_accountStartEquity;
      m_dailyLowEquity = m_accountStartEquity;
      
      // Calculate maximum allowed drawdown amount
      m_maxDrawdownAmount = m_accountStartBalance * (m_maxDailyDrawdownPercent / 100.0);
      
      // CRITICAL FIX: Always reset lock on fresh initialization (new session)
      // This ensures the EA isn't stuck from a previous day's lock
      if(m_isLocked)
      {
         // Check if lock file is from a previous day
         bool savedLock = false;
         datetime lockTime = 0;
         double ddPercent = 0.0;
         
         if(ReadLockData(savedLock, lockTime, ddPercent))
         {
            MqlDateTime dt_current, dt_lock;
            TimeToStruct(current, dt_current);
            TimeToStruct(lockTime, dt_lock);
            
            // If lock is from a different day, reset it
            if(dt_current.day != dt_lock.day || dt_current.mon != dt_lock.mon || dt_current.year != dt_lock.year)
            {
               m_isLocked = false;
               m_currentDrawdownPercent = 0.0;
               Print("Drawdown protection: Stale lock from previous day detected - resetting");
               WriteLockData(false, current, 0.0);
            }
         }
         else
         {
            // Lock file couldn't be read - assume stale and reset
            m_isLocked = false;
            m_currentDrawdownPercent = 0.0;
            Print("Drawdown protection: Lock file unreadable - resetting to allow trading");
            WriteLockData(false, current, 0.0);
         }
      }
      
      return true;
   }
   
   // Convert datetimes to day values for comparison
   MqlDateTime dt_current, dt_last;
   TimeToStruct(current, dt_current);
   TimeToStruct(m_lastDayChecked, dt_last);
   
   // Check if we've moved to a new day (including skipped days like weekends)
   // Calculate day difference to catch multi-day gaps
   int dayDiff = (dt_current.year - dt_last.year) * 365 + 
                 (dt_current.day_of_year - dt_last.day_of_year);
   
   if(dayDiff >= 1)
   {
      m_lastDayChecked = current;
      
      // Reset account daily reference values
      m_accountStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_accountStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_dailyHighEquity = m_accountStartEquity;
      m_dailyLowEquity = m_accountStartEquity;
      
      // Calculate maximum allowed drawdown amount
      m_maxDrawdownAmount = m_accountStartBalance * (m_maxDailyDrawdownPercent / 100.0);
      
      // Reset lock status for a new day (if previously locked)
      if(m_isLocked)
      {
         m_isLocked = false;
         m_currentDrawdownPercent = 0.0;
         Print("Drawdown protection: New day detected (", dayDiff, " days passed), account lock reset");
         
         // Update lock file
         WriteLockData(false, current, 0.0);
      }
      
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Update current drawdown status                                    |
//+------------------------------------------------------------------+
bool CDrawdownProtection::UpdateDrawdownStatus()
{
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Update high/low water marks
   if(currentEquity > m_dailyHighEquity)
      m_dailyHighEquity = currentEquity;
      
   if(currentEquity < m_dailyLowEquity || m_dailyLowEquity == 0)
      m_dailyLowEquity = currentEquity;
   
   // Calculate current drawdown from highest point
   double drawdownFromHigh = m_dailyHighEquity - currentEquity;
   double drawdownPercentFromHigh = (drawdownFromHigh / m_accountStartBalance) * 100.0;
   
   // Calculate drawdown from start of day
   double drawdownFromStart = m_accountStartEquity - currentEquity;
   double drawdownPercentFromStart = (drawdownFromStart / m_accountStartBalance) * 100.0;
   
   // Use the larger of the two drawdown calculations
   m_currentDrawdownPercent = MathMax(drawdownPercentFromHigh, drawdownPercentFromStart);
   
   // Check if we need to lock the account
   if(!m_isLocked && m_currentDrawdownPercent >= m_maxDailyDrawdownPercent)
   {
      m_isLocked = true;
      Print("Drawdown protection: Account locked - Reached max daily drawdown of ", 
            DoubleToString(m_maxDailyDrawdownPercent, 2), "%, current DD: ", 
            DoubleToString(m_currentDrawdownPercent, 2), "%");
            
      // Save lock status to file
      WriteLockData(true, TimeCurrent(), m_currentDrawdownPercent);
      
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Process tick update for drawdown monitoring                       |
//+------------------------------------------------------------------+
bool CDrawdownProtection::ProcessTick()
{
   // Only process at intervals to improve performance
   datetime currentTime = TimeCurrent();
   if(currentTime - m_lastProcessTime < (m_isTesting ? 10 : 1))
      return true;
      
   m_lastProcessTime = currentTime;
   
   // Check for new day
   ResetDailyValues();
   
   // Update drawdown status
   UpdateDrawdownStatus();
   
   // Update losing streak detection
   UpdateLosingStreak();
   
   return true;
}

//+------------------------------------------------------------------+
//| Update losing streak detection based on trade history             |
//+------------------------------------------------------------------+
void CDrawdownProtection::UpdateLosingStreak()
{
   datetime currentTime = TimeCurrent();
   
   // Check if losing streak lock has expired
   if(m_losingStreakLocked)
   {
      double hoursPassed = (double)(currentTime - m_losingStreakLockTime) / 3600.0;
      if(hoursPassed >= m_losingStreakPauseHours)
      {
         m_losingStreakLocked = false;
         m_consecutiveLosses = 0;
         Print("Losing streak protection: Pause period ended after ", 
               DoubleToString(m_losingStreakPauseHours, 1), " hours. Trading resumed.");
      }
      return;  // Skip further processing while locked
   }
   
   // Only check trade history periodically (every 30 seconds live, 60 seconds in tester)
   int checkInterval = m_isTesting ? 60 : 30;
   if(currentTime - m_lastTradeCheckTime < checkInterval)
      return;
      
   m_lastTradeCheckTime = currentTime;
   
   // Select history for today
   datetime dayStart = StringToTime(TimeToString(currentTime, TIME_DATE));
   if(!HistorySelect(dayStart, currentTime))
      return;
      
   int totalDeals = HistoryDealsTotal();
   
   // Skip if no new deals
   if(totalDeals == m_lastHistoryDealsTotal)
      return;
      
   m_lastHistoryDealsTotal = totalDeals;
   
   // Count consecutive losses from most recent trades
   int consecutiveLosses = 0;
   
   // Iterate from most recent deal backwards
   for(int i = totalDeals - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0)
         continue;
      
      // Filter by magic number if specified (skip deals from other EAs)
      if(m_magicNumber != 0)
      {
         long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
         if(dealMagic != m_magicNumber)
            continue;
      }
         
      // Only check trade deals (not balance/deposit/withdrawal)
      ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry != DEAL_ENTRY_OUT && dealEntry != DEAL_ENTRY_INOUT)
         continue;
         
      double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      double dealCommission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      double dealSwap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
      double netProfit = dealProfit + dealCommission + dealSwap;
      
      if(netProfit < 0)
      {
         consecutiveLosses++;
      }
      else if(netProfit > 0)
      {
         // A winning trade breaks the streak
         break;
      }
      // Skip break-even trades (netProfit == 0)
   }
   
   m_consecutiveLosses = consecutiveLosses;
   
   // Check if we've hit the losing streak threshold
   if(m_consecutiveLosses >= m_maxConsecutiveLosses && !m_losingStreakLocked)
   {
      m_losingStreakLocked = true;
      m_losingStreakLockTime = currentTime;
      Print("Losing streak protection: Trading paused after ", m_consecutiveLosses,
            " consecutive losses. Will resume in ", DoubleToString(m_losingStreakPauseHours, 1), " hours.");
   }
}

//+------------------------------------------------------------------+
//| Manually lock the account                                         |
//+------------------------------------------------------------------+
bool CDrawdownProtection::LockAccount()
{
   m_isLocked = true;
   Print("Drawdown protection: Account manually locked");
   
   // Save lock status to file
   WriteLockData(true, TimeCurrent(), m_currentDrawdownPercent);
   
   return true;
}

//+------------------------------------------------------------------+
//| Manually unlock the account (use with caution)                    |
//+------------------------------------------------------------------+
bool CDrawdownProtection::UnlockAccount()
{
   m_isLocked = false;
   Print("Drawdown protection: Account manually unlocked");
   
   // Save lock status to file
   WriteLockData(false, TimeCurrent(), m_currentDrawdownPercent);
   
   return true;
}

//+------------------------------------------------------------------+
//| Get status text for display                                       |
//+------------------------------------------------------------------+
string CDrawdownProtection::GetStatusText()
{
   string lockStatus = "TRADING";
   if(m_isLocked)
      lockStatus = "LOCKED (Drawdown)";
   else if(m_losingStreakLocked)
      lockStatus = "PAUSED (Losing Streak)";
   
   string status = StringFormat(
      "Drawdown Protection Status:\n" +
      "Max Daily DD: %.2f%%\n" +
      "Current DD: %.2f%%\n" +
      "Account %s\n" +
      "Daily Start Balance: %.2f\n" +
      "Daily High Equity: %.2f\n" +
      "Current Equity: %.2f\n" +
      "Consecutive Losses: %d/%d",
      m_maxDailyDrawdownPercent,
      m_currentDrawdownPercent,
      lockStatus,
      m_accountStartBalance,
      m_dailyHighEquity,
      AccountInfoDouble(ACCOUNT_EQUITY),
      m_consecutiveLosses,
      m_maxConsecutiveLosses
   );
   
   return status;
}

#endif // DRAWDOWN_PROTECTION_MQH