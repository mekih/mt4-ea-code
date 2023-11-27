//+------------------------------------------------------------------+
//| Expert Advisor Template for MT4                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
// Global variables
int ticket1 = 0, ticket2 = 0;
bool order1Filled = false, order2Filled = false;
double trailingStop = 30; // Trailing stop in pips
double lotSize; // Calculated lot size based on SL and account leverage

//+------------------------------------------------------------------+
// Input parameters
input string filePath = "C:\\Path\\To\\Your\\trade_signals.txt"; // File path for the trade signals
input double SL_USD = 10; // Stop Loss in USD
input double TP_USD = 20; // Take Profit in USD
input int TrailStart = 30; // When to start trailing stop in pips

// Function prototypes
void ReadAndExecuteTradeSignals();
void ManageOrders();
bool CalculateLotSize(double& calculatedLotSize);
//+------------------------------------------------------------------+
//| Expert initialization function                  |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialization code here
    Print("EA initialized successfully");

    // Checking lot size calculation
    if (!CalculateLotSize(lotSize)) {
      // Handle error
      Print("Error in calculating lot size");
    }

    return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Calculate lot size based on SL in USD                            |
//+------------------------------------------------------------------+
bool CalculateLotSize(double& calculatedLotSize) {
   // Assuming that SL is set in terms of USD, we need to convert this to pips.
   // The pip value can vary based on the currency pair and lot size.
   
  // Calculate lot size and assign it to the passed parameter
  calculatedLotSize = lotSize; // Use the passed parameter 'calculatedLotSize'
  
   // Get the contract size of the symbol (e.g., 100,000 for standard lots in Forex).
   double contractSize = MarketInfo(Symbol(), MODE_LOTSIZE);

   // Get the number of digits and point size for accurate pip calculations.
   int digits = MarketInfo(Symbol(), MODE_DIGITS);
   double point = MarketInfo(Symbol(), MODE_POINT);

   // Calculate the pip value for one standard lot (e.g., for 100,000 units of currency).
   double pipValueStandardLot = PointToPipValue(point, digits, contractSize);

   // Calculate the number of pips that SL_USD corresponds to.
   // The formula depends on whether the account currency is the same as the quote currency of the pair.
   double pipsSL = SL_USD / pipValueStandardLot;

   // Calculate the lot size based on the leverage and the number of pips for SL.
   double leverage = AccountLeverage();
   double accountEquity = AccountEquity();
   double marginPerStandardLot = contractSize / leverage;
   lotSize = (accountEquity / marginPerStandardLot) * (pipsSL / 100);

    // Use 'calculatedLotSize' for calculations and assignments
    calculatedLotSize = NormalizeDouble(calculatedLotSize, 2); 

    if (calculatedLotSize < 0.01) {
        calculatedLotSize = 0.01;
        return false;
    }
    if (calculatedLotSize > 50) {
        calculatedLotSize = 50;
        return false;
    }

    Print("Calculated lot size: ", calculatedLotSize);
    return true;
}

// Usage in the calling function
if (!CalculateLotSize(lotSize)) {
  // Handle error
}
//+------------------------------------------------------------------+
//| Convert point value to pip value                                 |
//+------------------------------------------------------------------+
double PointToPipValue(double point, int digits, double contractSize)
  {
   double pip = point;
   if(digits == 5 || digits == 3) pip *= 10;
   return pip * contractSize;
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Main trading logic goes here
   ReadAndExecuteTradeSignals();

   // Check order status and manage orders
   ManageOrders();
  }

// Function to manage orders
void ManageOrders()
{
    // Check if orders are filled and adjust or close the other order
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS) && OrderSymbol() == Symbol())
        {
            // Check only market and pending orders
            if(OrderType() <= OP_SELL && OrderMagicNumber() == 0)
            {
                // Check if the order is not a pending order
                if(OrderTicket() == ticket1 && (OrderType() != OP_BUYSTOP && OrderType() != OP_SELLSTOP))
                    order1Filled = true;
                else if(OrderTicket() == ticket2 && (OrderType() != OP_BUYSTOP && OrderType() != OP_SELLSTOP))
                    order2Filled = true;

                // Implement trailing stop logic
                if(order1Filled || order2Filled)
                    AdjustTrailingStop(OrderTicket(), OrderOpenPrice());
            }
        }
    }

    // Cancel the other pending order if one is filled
if(order1Filled && !order2Filled)
{
  if(OrderSelect(ticket2, SELECT_BY_TICKET) && (OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP))
  {
    OrderDelete(ticket2);
  }
}
else if(order2Filled && !order1Filled)
{
  if(OrderSelect(ticket1, SELECT_BY_TICKET) && (OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP))
  {
    OrderDelete(ticket1);
  }
}

// Function to adjust trailing stop
void AdjustTrailingStop(int ticket, double orderOpenPrice)
  {
   double currentPrice = (OrderType() == OP_BUY) ? MarketInfo(Symbol(), MODE_ASK) : MarketInfo(Symbol(), MODE_BID);
   double trailingStopLoss = (OrderType() == OP_BUY) ? orderOpenPrice + trailingStop * Point : orderOpenPrice - trailingStop * Point;

   // Adjust the stop loss only in the direction of the trade
   if((OrderType() == OP_BUY && trailingStopLoss < currentPrice && trailingStopLoss > OrderStopLoss()) ||
      (OrderType() == OP_SELL && trailingStopLoss > currentPrice && trailingStopLoss < OrderStopLoss()))
     {
      OrderModify(ticket, OrderOpenPrice(), trailingStopLoss, OrderTakeProfit(), 0, OrderColor());
     }
  }

//+------------------------------------------------------------------+
//| Function to read and execute trade signals                       |
//+------------------------------------------------------------------+
void ReadAndExecuteTradeSignals()
  {
   string fileData;
   // Open the file
   int fileHandle = FileOpen(filePath, FILE_READ | FILE_TXT);
   if(fileHandle != INVALID_HANDLE)
     {
      while(!FileIsEnding(fileHandle))
        {
         fileData = FileReadString(fileHandle);
         // Parse and execute trades
         if(StringFind(fileData, "Sell Gold") >= 0 || StringFind(fileData, "Buy Gold") >= 0)
           {
            ParseAndExecuteTrade(fileData);
           }
        }
      FileClose(fileHandle);
     }
   else
     {
      Print("Failed to open file: ", filePath);
     }
  }

//+------------------------------------------------------------------+
//| Function to parse and execute a single trade signal              |
//+------------------------------------------------------------------+
void ParseAndExecuteTrade(string tradeData)
{
   string tradeType;
   double price1, price2;
   int ticket1 = 0, ticket2 = 0;

   // Parse the trade data
   if(StringFind(tradeData, "Sell Gold") >= 0) {
       tradeType = "SELL";
   } else if(StringFind(tradeData, "Buy Gold") >= 0) {
       tradeType = "BUY";
   } else {
       // Not a valid trade signal
       return;
   }

   // Extract prices
   int start = StringFind(tradeData, "@") + 1;
   int end = StringFind(tradeData, "-");
   string priceStr1 = StringSubstr(tradeData, start, end - start);
   string priceStr2 = StringSubstr(tradeData, end + 1);

   double price1 = StringToDouble(priceStr1);
   double price2 = StringToDouble(priceStr2);

   // Place two pending orders
   if (tradeType == "SELL") {
       // Place two sell stop orders
       ticket1 = OrderSend(Symbol(), OP_SELLSTOP, lotSize, price1, 3, 0, 0, "Sell Order 1", 0, 0, Red);
       if (ticket1 > 0) {
           Print("Sell Order 1 placed successfully. Ticket: ", ticket1);
       } else {
           Print("Error placing Sell Order 1. Error code: ", GetLastError());
       }

       ticket2 = OrderSend(Symbol(), OP_SELLSTOP, lotSize, price2, 3, 0, 0, "Sell Order 2", 0, 0, Red);
       if (ticket2 > 0) {
           Print("Sell Order 2 placed successfully. Ticket: ", ticket2);
       } else {
           Print("Error placing Sell Order 2. Error code: ", GetLastError());
       }
   } else if (tradeType == "BUY") {
       // Place two buy stop orders
       ticket1 = OrderSend(Symbol(), OP_BUYSTOP, lotSize, price1, 3, 0, 0, "Buy Order 1", 0, 0, Blue);
       if (ticket1 > 0) {
           Print("Buy Order 1 placed successfully. Ticket: ", ticket1);
       } else {
           Print("Error placing Buy Order 1. Error code: ", GetLastError());
       }

       ticket2 = OrderSend(Symbol(), OP_BUYSTOP, lotSize, price2, 3, 0, 0, "Buy Order 2", 0, 0, Blue);
       if (ticket2 > 0) {
           Print("Buy Order 2 placed successfully. Ticket: ", ticket2);
       } else {
           Print("Error placing Buy Order 2. Error code: ", GetLastError());
       }
   }
//+------------------------------------------------------------------+
