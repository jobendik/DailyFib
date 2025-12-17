#property strict

#ifndef TPSL_VISUALIZER_MQH
#define TPSL_VISUALIZER_MQH

#include "CommonUtils.mqh"

#define TPSL_OBJNAME_PREFIX "TpSlVis_"

// Order status enum for tracking
enum ENUM_ORDER_VISUALIZATION_STATUS
{
   ORDER_VIS_PENDING,   // Pending order
   ORDER_VIS_ACTIVE,    // Active position
   ORDER_VIS_CANCELED,  // Canceled order
   ORDER_VIS_CLOSED     // Completed trade
};

// Custom tracking for order status
struct OrderTrackingInfo 
{
   ulong    ticket;
   bool     isBuy;
   bool     isPending;
   bool     isVisualized;
   ENUM_ORDER_VISUALIZATION_STATUS status;
   datetime time;
   datetime closeTime;
   double   entryPrice;
   double   tp;
   double   sl;
};

//+------------------------------------------------------------------+
//| Comprehensive TP/SL visualization and tracking class              |
//+------------------------------------------------------------------+
class CTpSlVisualizer
{
private:
   // Configuration
   bool     m_isEnabled;
   color    m_tpColor;
   color    m_slColor;
   color    m_tpFinishedColor;
   color    m_slFinishedColor;
   color    m_tpCanceledColor;
   color    m_slCanceledColor;
   int      m_transparency;
   string   m_namePrefix;
   int      m_magicNumber;
   bool     m_inBacktestMode;
   
   // Order tracking
   OrderTrackingInfo m_orderTracking[];
   int      m_orderTrackingCount;
   datetime m_lastHistoryCheck;
   int      m_syncCounter;
   int      m_syncFrequency;
   
   // Internal tracking methods
   void MarkOrderFinishedInternal(ulong ticket, datetime endTime, ENUM_ORDER_VISUALIZATION_STATUS status);
   void ProcessOrderSyncInternal();
   void VisualizeOrdersInternal();
   void UpdateVisualizationForOrder(int orderIndex);
   
public:
   CTpSlVisualizer();
   ~CTpSlVisualizer();
   
   bool Init(int magicNumber, bool enabled = true, 
            color tpColor = clrLimeGreen, 
            color slColor = clrRed, 
            color tpFinishedColor = clrDarkGreen, 
            color slFinishedColor = clrMaroon,
            color tpCanceledColor = clrDimGray,
            color slCanceledColor = clrGray,
            int transparency = 90);
   
   // Main public methods
   void ProcessTick();
   void SyncOrders();
   void ProcessOrderEvent(const MqlTradeTransaction& trans, 
                        const MqlTradeRequest& request, 
                        const MqlTradeResult& result);
   
   // Enable/disable visualization
   bool IsEnabled() const { return m_isEnabled; }
   void SetEnabled(bool enabled) { m_isEnabled = enabled; }
   
   // Force update all orders (for daily processing)
   void ForceFullUpdate();
   
   // Helper methods made public for direct access
   string CreateObjectName(string type, ulong ticket)
   {
      return m_namePrefix + type + "_" + IntegerToString(ticket);
   }
   
   void DrawRectangle(string objName, datetime startTime, datetime endTime, 
                     double price1, double price2, color clr);
                     
   void AddOrderTracking(ulong ticket, bool isBuy, bool isPending, datetime time, 
                       double entryPrice, double tp, double sl);
   
   // Color getters for direct visualization
   color GetTpColor() const { return m_tpColor; }
   color GetSlColor() const { return m_slColor; }
   color GetTpFinishedColor() const { return m_tpFinishedColor; }
   color GetSlFinishedColor() const { return m_slFinishedColor; }
   color GetTpCanceledColor() const { return m_tpCanceledColor; }
   color GetSlCanceledColor() const { return m_slCanceledColor; }
   
   // Direct visualization methods
   void CreateTpSlVisualization(ulong ticket, bool isBuy, datetime startTime, 
                               double entryPrice, double tp, double sl);
   
   void UpdateTpSlVisualization(ulong ticket, bool isBuy, double entryPrice, 
                               double tp, double sl);
   
   void FinishTpSlVisualization(ulong ticket, datetime endTime, bool isSuccessful);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTpSlVisualizer::CTpSlVisualizer()
{
   m_isEnabled = true;
   m_tpColor = clrLimeGreen;
   m_slColor = clrRed;
   m_tpFinishedColor = clrDarkGreen;
   m_slFinishedColor = clrMaroon;
   m_tpCanceledColor = clrDimGray;
   m_slCanceledColor = clrGray;
   m_transparency = 90;
   m_namePrefix = TPSL_OBJNAME_PREFIX;
   m_magicNumber = 1;
   m_inBacktestMode = MQLInfoInteger(MQL_TESTER);
   
   m_orderTrackingCount = 0;
   ArrayResize(m_orderTracking, 0);
   m_lastHistoryCheck = 0;
   m_syncCounter = 0;
   m_syncFrequency = m_inBacktestMode ? 100 : 20;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTpSlVisualizer::~CTpSlVisualizer()
{
   // Do not delete objects - they need to stay on the chart
}

//+------------------------------------------------------------------+
//| Initialize the visualizer                                         |
//+------------------------------------------------------------------+
bool CTpSlVisualizer::Init(int magicNumber, bool enabled = true, 
                          color tpColor = clrLimeGreen, 
                          color slColor = clrRed, 
                          color tpFinishedColor = clrDarkGreen, 
                          color slFinishedColor = clrMaroon,
                          color tpCanceledColor = clrDimGray,
                          color slCanceledColor = clrGray,
                          int transparency = 90)
{
   m_isEnabled = enabled;
   m_tpColor = tpColor;
   m_slColor = slColor;
   m_tpFinishedColor = tpFinishedColor;
   m_slFinishedColor = slFinishedColor;
   m_tpCanceledColor = tpCanceledColor;
   m_slCanceledColor = slCanceledColor;
   m_transparency = transparency;
   m_magicNumber = magicNumber;
   m_inBacktestMode = MQLInfoInteger(MQL_TESTER);
   
   // Reset order tracking
   m_orderTrackingCount = 0;
   ArrayResize(m_orderTracking, 0);
   m_lastHistoryCheck = 0;
   m_syncCounter = 0;
   
   return true;
}

//+------------------------------------------------------------------+
//| Create or update a visualization rectangle                        |
//+------------------------------------------------------------------+
void CTpSlVisualizer::DrawRectangle(string objName, datetime startTime, datetime endTime, 
                                  double price1, double price2, color clr)
{
   // Create or update rectangle without deleting first (more efficient)
   if(!ObjectCreate(0, objName, OBJ_RECTANGLE, 0, startTime, price1, endTime, price2))
   {
      // If object already exists, update its properties
      ObjectSetInteger(0, objName, OBJPROP_TIME, 0, startTime);
      ObjectSetInteger(0, objName, OBJPROP_TIME, 1, endTime);
      ObjectSetDouble(0, objName, OBJPROP_PRICE, 0, price1);
      ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, price2);
   }
   
   // Set visual properties
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objName, OBJPROP_FILL, true);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, ColorBlend(clr, clrWhite, m_transparency));
   ObjectSetInteger(0, objName, OBJPROP_ZORDER, 0); // Put in background
}

//+------------------------------------------------------------------+
//| Add a new order to tracking                                       |
//+------------------------------------------------------------------+
void CTpSlVisualizer::AddOrderTracking(ulong ticket, bool isBuy, bool isPending, datetime time, 
                                     double entryPrice, double tp, double sl)
{
   // Make sure we're not adding duplicates
   for(int i = 0; i < m_orderTrackingCount; i++)
   {
      if(m_orderTracking[i].ticket == ticket)
         return;
   }
   
   // Resize array if needed
   if(m_orderTrackingCount >= ArraySize(m_orderTracking))
      ArrayResize(m_orderTracking, m_orderTrackingCount + 10);
      
   // Add new order
   m_orderTracking[m_orderTrackingCount].ticket = ticket;
   m_orderTracking[m_orderTrackingCount].isBuy = isBuy;
   m_orderTracking[m_orderTrackingCount].isPending = isPending;
   m_orderTracking[m_orderTrackingCount].isVisualized = false;
   m_orderTracking[m_orderTrackingCount].status = isPending ? ORDER_VIS_PENDING : ORDER_VIS_ACTIVE;
   m_orderTracking[m_orderTrackingCount].time = time;
   m_orderTracking[m_orderTrackingCount].closeTime = 0;
   m_orderTracking[m_orderTrackingCount].entryPrice = entryPrice;
   m_orderTracking[m_orderTrackingCount].tp = tp;
   m_orderTracking[m_orderTrackingCount].sl = sl;
   
   m_orderTrackingCount++;
}

//+------------------------------------------------------------------+
//| Update visualization for a specific order                         |
//+------------------------------------------------------------------+
void CTpSlVisualizer::UpdateVisualizationForOrder(int orderIndex)
{
   if(!m_isEnabled || orderIndex < 0 || orderIndex >= m_orderTrackingCount)
      return;
      
   OrderTrackingInfo order = m_orderTracking[orderIndex];
   
   if(order.tp == 0 && order.sl == 0)
      return; // No TP/SL to visualize
      
   // Determine visualization end time
   datetime endTime = order.closeTime;
   if(endTime == 0) // Still active
   {
      endTime = order.time + PeriodSeconds(PERIOD_D1) * 30; // 30 days in future
   }
   
   // Determine colors based on order status
   color tpColor = m_tpColor;
   color slColor = m_slColor;
   
   switch(order.status)
   {
      case ORDER_VIS_ACTIVE:
      case ORDER_VIS_PENDING:
         tpColor = m_tpColor;
         slColor = m_slColor;
         break;
         
      case ORDER_VIS_CLOSED:
         tpColor = m_tpFinishedColor;
         slColor = m_slFinishedColor;
         break;
         
      case ORDER_VIS_CANCELED:
         tpColor = m_tpCanceledColor;
         slColor = m_slCanceledColor;
         break;
   }
   
   // Draw TP rectangle if TP is set
   if(order.tp != 0)
   {
      string tpObjName = CreateObjectName("TP", order.ticket);
      
      if(order.isBuy)
         DrawRectangle(tpObjName, order.time, endTime, order.tp, order.entryPrice, tpColor);
      else
         DrawRectangle(tpObjName, order.time, endTime, order.entryPrice, order.tp, tpColor);
   }
   
   // Draw SL rectangle if SL is set
   if(order.sl != 0)
   {
      string slObjName = CreateObjectName("SL", order.ticket);
      
      if(order.isBuy)
         DrawRectangle(slObjName, order.time, endTime, order.entryPrice, order.sl, slColor);
      else
         DrawRectangle(slObjName, order.time, endTime, order.sl, order.entryPrice, slColor);
   }
   
   order.isVisualized = true;
}

//+------------------------------------------------------------------+
//| Create or update visualizations for all orders                    |
//+------------------------------------------------------------------+
void CTpSlVisualizer::VisualizeOrdersInternal()
{
   if(!m_isEnabled)
      return;
      
   for(int i = 0; i < m_orderTrackingCount; i++)
   {
      // Create or update visualizations for all orders
      if(!m_orderTracking[i].isVisualized || 
         (m_orderTracking[i].status == ORDER_VIS_CANCELED || 
          m_orderTracking[i].status == ORDER_VIS_CLOSED))
      {
         UpdateVisualizationForOrder(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Mark an order as finished                                         |
//+------------------------------------------------------------------+
void CTpSlVisualizer::MarkOrderFinishedInternal(ulong ticket, datetime endTime, ENUM_ORDER_VISUALIZATION_STATUS status)
{
   if(!m_isEnabled)
      return;
      
   // Update order status in tracking
   for(int i = 0; i < m_orderTrackingCount; i++)
   {
      if(m_orderTracking[i].ticket == ticket)
      {
         m_orderTracking[i].status = status;
         m_orderTracking[i].closeTime = endTime;
         
         // Force re-visualization on next update
         m_orderTracking[i].isVisualized = false;
         break;
      }
   }
   
   // Update order visualization immediately
   VisualizeOrdersInternal();
}

//+------------------------------------------------------------------+
//| Synchronize order data                                            |
//+------------------------------------------------------------------+
void CTpSlVisualizer::ProcessOrderSyncInternal()
{
   if(!m_isEnabled)
      return;
      
   // Limit processing frequency for performance
   if(m_inBacktestMode && ++m_syncCounter % m_syncFrequency != 0)
      return;
   
   m_syncCounter = 0;
   
   // Store active tickets for comparison
   ulong activeTickets[];
   int activeCount = 0;
   
   // Check pending orders first
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderGetInteger(ORDER_MAGIC) == m_magicNumber)
      {
         // Add to active list
         ArrayResize(activeTickets, activeCount + 1);
         activeTickets[activeCount++] = ticket;
         
         // Look for this ticket in our tracking
         bool foundTicket = false;
         for(int j = 0; j < m_orderTrackingCount; j++)
         {
            if(m_orderTracking[j].ticket == ticket)
            {
               foundTicket = true;
               
               // Skip if already processed as finished
               if(m_orderTracking[j].status == ORDER_VIS_CLOSED || 
                  m_orderTracking[j].status == ORDER_VIS_CANCELED)
                  break;
                  
               // Check if TP/SL changed
               double tp = OrderGetDouble(ORDER_TP);
               double sl = OrderGetDouble(ORDER_SL);
               
               bool valueChanged = (m_orderTracking[j].tp != tp || m_orderTracking[j].sl != sl);
               
               if(valueChanged)
               {
                  // Update tracking values
                  m_orderTracking[j].tp = tp;
                  m_orderTracking[j].sl = sl;
                  
                  // Force redraw visualization
                  m_orderTracking[j].isVisualized = false;
               }
               
               break;
            }
         }
         
         // If order not found in tracking, add it
         if(!foundTicket)
         {
            bool isBuy = (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY || 
                        OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT || 
                        OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP);
                        
            AddOrderTracking(
               ticket,
               isBuy,
               true,
               (datetime)OrderGetInteger(ORDER_TIME_SETUP),
               OrderGetDouble(ORDER_PRICE_OPEN),
               OrderGetDouble(ORDER_TP),
               OrderGetDouble(ORDER_SL)
            );
         }
      }
   }
   
   // Now check positions
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetInteger(POSITION_MAGIC) == m_magicNumber)
      {
         // Add to active list
         ArrayResize(activeTickets, activeCount + 1);
         activeTickets[activeCount++] = ticket;
         
         // Look for this ticket in our tracking
         bool foundTicket = false;
         for(int j = 0; j < m_orderTrackingCount; j++)
         {
            if(m_orderTracking[j].ticket == ticket)
            {
               foundTicket = true;
               
               // Skip if already processed as finished
               if(m_orderTracking[j].status == ORDER_VIS_CLOSED || 
                  m_orderTracking[j].status == ORDER_VIS_CANCELED)
                  break;
                  
               // Update status from pending to active
               if(m_orderTracking[j].isPending)
               {
                  m_orderTracking[j].isPending = false;
                  m_orderTracking[j].status = ORDER_VIS_ACTIVE;
               }
                  
               // Check if TP/SL changed
               double tp = PositionGetDouble(POSITION_TP);
               double sl = PositionGetDouble(POSITION_SL);
               
               bool valueChanged = (m_orderTracking[j].tp != tp || m_orderTracking[j].sl != sl);
               
               if(valueChanged)
               {
                  // Update tracking values
                  m_orderTracking[j].tp = tp;
                  m_orderTracking[j].sl = sl;
                  
                  // Force redraw visualization
                  m_orderTracking[j].isVisualized = false;
               }
               
               break;
            }
         }
         
         // If position not found in tracking, add it
         if(!foundTicket)
         {
            bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
                        
            AddOrderTracking(
               ticket,
               isBuy,
               false,
               (datetime)PositionGetInteger(POSITION_TIME),
               PositionGetDouble(POSITION_PRICE_OPEN),
               PositionGetDouble(POSITION_TP),
               PositionGetDouble(POSITION_SL)
            );
         }
      }
   }
   
   // Check for orders that need to be marked as finished
   // Limit this expensive check to run rarely
   datetime currentTime = TimeCurrent();
   if(currentTime - m_lastHistoryCheck < 60 && !m_inBacktestMode)
   {
      // Visualize all orders before returning
      VisualizeOrdersInternal();
      return;
   }
      
   m_lastHistoryCheck = currentTime;
   
   // Check for history orders to ensure we catch everything
   HistorySelect(0, currentTime);
   
   // First, check history orders to make sure we track all orders that have ever existed
   for(int i = 0; i < HistoryOrdersTotal(); i++)
   {
      ulong historyOrderTicket = HistoryOrderGetTicket(i);
      
      if(historyOrderTicket > 0 && HistoryOrderGetInteger(historyOrderTicket, ORDER_MAGIC) == m_magicNumber)
      {
         // Check if we're already tracking this order
         bool foundInTracking = false;
         for(int j = 0; j < m_orderTrackingCount; j++)
         {
            if(m_orderTracking[j].ticket == historyOrderTicket)
            {
               foundInTracking = true;
               break;
            }
         }
         
         // If not found, add it to tracking
         if(!foundInTracking)
         {
            ENUM_ORDER_STATE orderState = (ENUM_ORDER_STATE)HistoryOrderGetInteger(historyOrderTicket, ORDER_STATE);
            
            // Skip orders that don't have TP/SL
            double tp = HistoryOrderGetDouble(historyOrderTicket, ORDER_TP);
            double sl = HistoryOrderGetDouble(historyOrderTicket, ORDER_SL);
            
            if(tp == 0 && sl == 0)
               continue;
               
            bool isBuy = (HistoryOrderGetInteger(historyOrderTicket, ORDER_TYPE) == ORDER_TYPE_BUY || 
                        HistoryOrderGetInteger(historyOrderTicket, ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT || 
                        HistoryOrderGetInteger(historyOrderTicket, ORDER_TYPE) == ORDER_TYPE_BUY_STOP);
                        
            datetime orderTime = (datetime)HistoryOrderGetInteger(historyOrderTicket, ORDER_TIME_SETUP);
            datetime orderDoneTime = (datetime)HistoryOrderGetInteger(historyOrderTicket, ORDER_TIME_DONE);
            double entryPrice = HistoryOrderGetDouble(historyOrderTicket, ORDER_PRICE_OPEN);
            
            // Add to tracking
            AddOrderTracking(
               historyOrderTicket,
               isBuy,
               true,
               orderTime,
               entryPrice,
               tp,
               sl
            );
            
            // Update status based on order state
            if(orderState == ORDER_STATE_FILLED)
            {
               // Order was executed, find the deal in history
               for(int j = 0; j < m_orderTrackingCount; j++)
               {
                  if(m_orderTracking[j].ticket == historyOrderTicket)
                  {
                     m_orderTracking[j].status = ORDER_VIS_CLOSED;
                     m_orderTracking[j].closeTime = orderDoneTime > 0 ? orderDoneTime : currentTime;
                     m_orderTracking[j].isVisualized = false;
                     break;
                  }
               }
            }
            else if(orderState == ORDER_STATE_CANCELED || orderState == ORDER_STATE_REJECTED || orderState == ORDER_STATE_EXPIRED)
            {
               // Order was canceled
               for(int j = 0; j < m_orderTrackingCount; j++)
               {
                  if(m_orderTracking[j].ticket == historyOrderTicket)
                  {
                     m_orderTracking[j].status = ORDER_VIS_CANCELED;
                     m_orderTracking[j].closeTime = orderDoneTime > 0 ? orderDoneTime : currentTime;
                     m_orderTracking[j].isVisualized = false;
                     break;
                  }
               }
            }
         }
      }
   }
   
   // Check for positions (deals) in history
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      
      if(dealTicket > 0 && HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == m_magicNumber)
      {
         ulong positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         
         if(positionId > 0)
         {
            // Check if this position is in our tracking
            bool foundInTracking = false;
            for(int j = 0; j < m_orderTrackingCount; j++)
            {
               if(m_orderTracking[j].ticket == positionId)
               {
                  foundInTracking = true;
                  
                  // If position is closed (out entry) and status isn't set to closed yet
                  if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT && 
                     m_orderTracking[j].status != ORDER_VIS_CLOSED)
                  {
                     m_orderTracking[j].status = ORDER_VIS_CLOSED;
                     m_orderTracking[j].closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
                     m_orderTracking[j].isVisualized = false;
                  }
                  
                  break;
               }
            }
         }
      }
   }
   
   // Check tracked orders that are no longer active
   for(int i = 0; i < m_orderTrackingCount; i++)
   {
      // Skip orders already marked as finished
      if(m_orderTracking[i].status == ORDER_VIS_CLOSED || 
         m_orderTracking[i].status == ORDER_VIS_CANCELED)
         continue;
         
      // Check if order is still active
      bool isActive = false;
      for(int j = 0; j < activeCount; j++)
      {
         if(activeTickets[j] == m_orderTracking[i].ticket)
         {
            isActive = true;
            break;
         }
      }
      
      // If order is no longer active
      if(!isActive)
      {
         // Check history to determine if it was filled or canceled
         bool foundInHistory = false;
         
         for(int j = 0; j < HistoryOrdersTotal(); j++)
         {
            ulong historyOrderTicket = HistoryOrderGetTicket(j);
            
            if(historyOrderTicket == m_orderTracking[i].ticket)
            {
               foundInHistory = true;
               ENUM_ORDER_STATE orderState = (ENUM_ORDER_STATE)HistoryOrderGetInteger(historyOrderTicket, ORDER_STATE);
               datetime orderDoneTime = (datetime)HistoryOrderGetInteger(historyOrderTicket, ORDER_TIME_DONE);
               
               if(orderState == ORDER_STATE_FILLED)
               {
                  m_orderTracking[i].status = ORDER_VIS_CLOSED;
                  m_orderTracking[i].closeTime = orderDoneTime > 0 ? orderDoneTime : currentTime;
               }
               else
               {
                  m_orderTracking[i].status = ORDER_VIS_CANCELED;
                  m_orderTracking[i].closeTime = orderDoneTime > 0 ? orderDoneTime : currentTime;
               }
               
               m_orderTracking[i].isVisualized = false;
               break;
            }
         }
         
         // If not found in history, mark as canceled (fall back)
         if(!foundInHistory && m_orderTracking[i].status != ORDER_VIS_CLOSED)
         {
            m_orderTracking[i].status = ORDER_VIS_CANCELED;
            m_orderTracking[i].closeTime = currentTime;
            m_orderTracking[i].isVisualized = false;
         }
      }
   }
   
   // Visualize all orders
   VisualizeOrdersInternal();
}

//+------------------------------------------------------------------+
//| Process order events from MqlTradeTransaction                     |
//+------------------------------------------------------------------+
void CTpSlVisualizer::ProcessOrderEvent(const MqlTradeTransaction& trans, 
                                      const MqlTradeRequest& request, 
                                      const MqlTradeResult& result)
{
   if(!m_isEnabled)
      return;
      
   // Check if this is our EA's order from request
   if(request.magic == m_magicNumber)
   {
      // Process based on transaction type
      switch(trans.type)
      {
         // New order placed
         case TRADE_TRANSACTION_ORDER_ADD:
            if(trans.order_state == ORDER_STATE_PLACED && trans.order > 0)
            {
               // Select order to get details
               if(OrderSelect(trans.order))
               {
                  bool isBuy = (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY || 
                              OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT || 
                              OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP);
                  
                  // Skip if order has no TP/SL
                  double tp = OrderGetDouble(ORDER_TP);
                  double sl = OrderGetDouble(ORDER_SL);
                  
                  if(tp == 0 && sl == 0)
                     break;
                     
                  // Add to tracking
                  AddOrderTracking(
                     trans.order,
                     isBuy,
                     true,
                     (datetime)OrderGetInteger(ORDER_TIME_SETUP),
                     OrderGetDouble(ORDER_PRICE_OPEN),
                     tp,
                     sl
                  );
                  
                  // Visualize immediately
                  VisualizeOrdersInternal();
               }
            }
            break;
            
         // Order canceled
         case TRADE_TRANSACTION_ORDER_DELETE:
            if(trans.order > 0)
            {
               // Mark as canceled
               for(int i = 0; i < m_orderTrackingCount; i++)
               {
                  if(m_orderTracking[i].ticket == trans.order && 
                     m_orderTracking[i].status != ORDER_VIS_CANCELED && 
                     m_orderTracking[i].status != ORDER_VIS_CLOSED)
                  {
                     m_orderTracking[i].status = ORDER_VIS_CANCELED;
                     m_orderTracking[i].closeTime = TimeCurrent();
                     m_orderTracking[i].isVisualized = false;
                     
                     // Update visualization
                     VisualizeOrdersInternal();
                     break;
                  }
               }
            }
            break;
            
         // Position closed
         case TRADE_TRANSACTION_POSITION:
            if(trans.position > 0 && trans.order_state == ORDER_STATE_FILLED)
            {
               // Mark position as closed
               for(int i = 0; i < m_orderTrackingCount; i++)
               {
                  if(m_orderTracking[i].ticket == trans.position && 
                     m_orderTracking[i].status != ORDER_VIS_CLOSED)
                  {
                     m_orderTracking[i].status = ORDER_VIS_CLOSED;
                     m_orderTracking[i].closeTime = TimeCurrent();
                     m_orderTracking[i].isVisualized = false;
                     
                     // Update visualization
                     VisualizeOrdersInternal();
                     break;
                  }
               }
            }
            break;
            
         // Order modified
         case TRADE_TRANSACTION_ORDER_UPDATE:
            SyncOrders(); // Full sync to catch TP/SL changes
            break;
      }
   }
   // Check if this is our EA's order from position or order select
   else if(trans.order > 0 || trans.position > 0)
   {
      bool isOurOrder = false;
      
      // Check order first
      if(trans.order > 0 && OrderSelect(trans.order))
         isOurOrder = (OrderGetInteger(ORDER_MAGIC) == m_magicNumber);
         
      // Then check position
      if(!isOurOrder && trans.position > 0 && PositionSelectByTicket(trans.position))
         isOurOrder = (PositionGetInteger(POSITION_MAGIC) == m_magicNumber);
         
      if(isOurOrder)
      {
         // Process the event through a full sync
         SyncOrders();
      }
   }
}

//+------------------------------------------------------------------+
//| Process tick - called from OnTick                                 |
//+------------------------------------------------------------------+
void CTpSlVisualizer::ProcessTick()
{
   if(!m_isEnabled)
      return;
   
   static int tickCounter = 0;
   
   // Check orders more frequently (100 ticks instead of 5000)
   if(++tickCounter > 100)
   {
      tickCounter = 0;
      ProcessOrderSyncInternal();
   }
}

//+------------------------------------------------------------------+
//| Sync orders - called when orders are likely to have changed       |
//+------------------------------------------------------------------+
void CTpSlVisualizer::SyncOrders()
{
   if(!m_isEnabled)
      return;
      
   ProcessOrderSyncInternal();
}

//+------------------------------------------------------------------+
//| Force full update of all orders (for daily processing)            |
//+------------------------------------------------------------------+
void CTpSlVisualizer::ForceFullUpdate()
{
   if(!m_isEnabled)
      return;
   
   // Do a full history check
   m_lastHistoryCheck = 0;
   ProcessOrderSyncInternal();
   
   // Make sure all orders are visualized
   VisualizeOrdersInternal();
}

//+------------------------------------------------------------------+
//| Direct visualization of TP/SL for new orders                      |
//+------------------------------------------------------------------+
void CTpSlVisualizer::CreateTpSlVisualization(ulong ticket, bool isBuy, datetime startTime, 
                                           double entryPrice, double tp, double sl)
{
   if(!m_isEnabled)
      return;
   
   // Add to tracking
   AddOrderTracking(ticket, isBuy, true, startTime, entryPrice, tp, sl);
   
   // Create visualizations directly
   if(tp != 0)
   {
      string tpObjName = CreateObjectName("TP", ticket);
      
      if(isBuy)
         DrawRectangle(tpObjName, startTime, startTime + PeriodSeconds(PERIOD_D1) * 30, tp, entryPrice, m_tpColor);
      else
         DrawRectangle(tpObjName, startTime, startTime + PeriodSeconds(PERIOD_D1) * 30, entryPrice, tp, m_tpColor);
   }
   
   if(sl != 0)
   {
      string slObjName = CreateObjectName("SL", ticket);
      
      if(isBuy)
         DrawRectangle(slObjName, startTime, startTime + PeriodSeconds(PERIOD_D1) * 30, entryPrice, sl, m_slColor);
      else
         DrawRectangle(slObjName, startTime, startTime + PeriodSeconds(PERIOD_D1) * 30, sl, entryPrice, m_slColor);
   }
}

//+------------------------------------------------------------------+
//| Direct update of TP/SL visualization for modified orders          |
//+------------------------------------------------------------------+
void CTpSlVisualizer::UpdateTpSlVisualization(ulong ticket, bool isBuy, double entryPrice, 
                                           double tp, double sl)
{
   if(!m_isEnabled)
      return;
   
   // Find the order in tracking
   int orderIndex = -1;
   for(int i = 0; i < m_orderTrackingCount; i++)
   {
      if(m_orderTracking[i].ticket == ticket)
      {
         orderIndex = i;
         break;
      }
   }
   
   if(orderIndex < 0)
   {
      // If not found, add it now
      datetime startTime = TimeCurrent();
      AddOrderTracking(ticket, isBuy, true, startTime, entryPrice, tp, sl);
      
      // Find the index after adding
      for(int i = 0; i < m_orderTrackingCount; i++)
      {
         if(m_orderTracking[i].ticket == ticket)
         {
            orderIndex = i;
            break;
         }
      }
   }
   else
   {
      // Update the tracking info
      m_orderTracking[orderIndex].entryPrice = entryPrice;
      m_orderTracking[orderIndex].tp = tp;
      m_orderTracking[orderIndex].sl = sl;
      m_orderTracking[orderIndex].isVisualized = false; // Force redraw
   }
   
   // Directly update visualization rectangles
   if(orderIndex >= 0)
   {
      // Determine visualization end time
      datetime endTime = TimeCurrent() + PeriodSeconds(PERIOD_D1) * 30; // 30 days in future
      
      // Draw TP rectangle if TP is set
      if(tp != 0)
      {
         string tpObjName = CreateObjectName("TP", ticket);
         
         if(isBuy)
            DrawRectangle(tpObjName, m_orderTracking[orderIndex].time, endTime, tp, entryPrice, m_tpColor);
         else
            DrawRectangle(tpObjName, m_orderTracking[orderIndex].time, endTime, entryPrice, tp, m_tpColor);
      }
      
      // Draw SL rectangle if SL is set
      if(sl != 0)
      {
         string slObjName = CreateObjectName("SL", ticket);
         
         if(isBuy)
            DrawRectangle(slObjName, m_orderTracking[orderIndex].time, endTime, entryPrice, sl, m_slColor);
         else
            DrawRectangle(slObjName, m_orderTracking[orderIndex].time, endTime, sl, entryPrice, m_slColor);
      }
   }
}

//+------------------------------------------------------------------+
//| Direct finalization of TP/SL visualization for closed/canceled    |
//+------------------------------------------------------------------+
void CTpSlVisualizer::FinishTpSlVisualization(ulong ticket, datetime endTime, bool isSuccessful)
{
   if(!m_isEnabled)
      return;
   
   // Mark as finished in tracking
   ENUM_ORDER_VISUALIZATION_STATUS status = isSuccessful ? ORDER_VIS_CLOSED : ORDER_VIS_CANCELED;
   MarkOrderFinishedInternal(ticket, endTime, status);
}

#endif // TPSL_VISUALIZER_MQH