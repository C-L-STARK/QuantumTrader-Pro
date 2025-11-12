//+------------------------------------------------------------------+
//|                                                  QuickHedge.mq4  |
//|                                  QuantumTrader-Pro ML Trading    |
//|                        Quick Hedge Utility Script/EA             |
//+------------------------------------------------------------------+
#property copyright "QuantumTrader-Pro"
#property link      "https://github.com/quantumtrader-pro"
#property version   "1.00"
#property strict

// Script can run as both script and EA
#property script_show_inputs
#property show_inputs

// Input parameters
input double   HedgeRatio = 1.0;              // Hedge ratio (1.0 = full hedge)
input bool     AutoAdjustLots = true;         // Auto-adjust lot sizes
input double   MinLotSize = 0.01;             // Minimum lot size
input double   MaxLotSize = 10.0;             // Maximum lot size
input int      Slippage = 3;                  // Allowed slippage (pips)
input bool     HedgeAllPositions = true;      // Hedge all open positions
input string   SpecificSymbol = "";           // Specific symbol to hedge (empty = current)
input bool     UseBalanceProtection = true;   // Balance protection mode
input double   MaxRiskPercent = 2.0;          // Max risk per hedge (% of balance)
input bool     EnableEmergencyMode = false;   // Emergency hedge mode
input color    BuyHedgeColor = clrDodgerBlue; // Buy hedge marker color
input color    SellHedgeColor = clrOrange;    // Sell hedge marker color
input bool     ShowHedgeInfo = true;          // Display hedge information
input bool     EnableNotifications = true;    // Enable push notifications

// Global variables
string scriptName = "QuickHedge";
int hedgeCount = 0;
double totalHedgedVolume = 0.0;
datetime lastHedgeTime = 0;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("========================================");
    Print("QuickHedge started");
    Print("========================================");

    // Validate parameters
    if(!ValidateParameters())
    {
        Print("Error: Invalid parameters");
        return;
    }

    // Display current positions
    DisplayCurrentPositions();

    // Execute hedge strategy
    if(EnableEmergencyMode)
    {
        Print("EMERGENCY HEDGE MODE ACTIVATED");
        ExecuteEmergencyHedge();
    }
    else if(HedgeAllPositions)
    {
        ExecuteFullHedge();
    }
    else
    {
        ExecuteSymbolHedge();
    }

    // Display results
    DisplayHedgeResults();

    // Send notifications
    if(EnableNotifications && hedgeCount > 0)
    {
        SendNotification(StringFormat("QuickHedge: %d positions hedged, Volume: %.2f",
                                       hedgeCount, totalHedgedVolume));
    }

    Print("========================================");
    Print("QuickHedge completed");
    Print("========================================");
}

//+------------------------------------------------------------------+
//| Expert initialization function (if used as EA)                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print(scriptName, " initialized as Expert Advisor");

    // Create emergency hedge button
    if(EnableEmergencyMode)
    {
        CreateEmergencyButton();
    }

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    RemoveEmergencyButton();
    Print(scriptName, " deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function (if used as EA)                            |
//+------------------------------------------------------------------+
void OnTick()
{
    // EA mode: monitor for emergency conditions
    if(EnableEmergencyMode)
    {
        CheckEmergencyConditions();
    }
}

//+------------------------------------------------------------------+
//| Chart event function (for button clicks)                        |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        if(sparam == scriptName + "_EmergencyBtn")
        {
            Print("Emergency Hedge Button Clicked!");
            ExecuteEmergencyHedge();

            // Reset button
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw();
        }
    }
}

//+------------------------------------------------------------------+
//| Validate input parameters                                        |
//+------------------------------------------------------------------+
bool ValidateParameters()
{
    if(HedgeRatio <= 0.0 || HedgeRatio > 2.0)
    {
        Print("Error: HedgeRatio must be between 0.0 and 2.0");
        return false;
    }

    if(MinLotSize < 0.01)
    {
        Print("Error: MinLotSize must be >= 0.01");
        return false;
    }

    if(MaxLotSize < MinLotSize)
    {
        Print("Error: MaxLotSize must be >= MinLotSize");
        return false;
    }

    if(MaxRiskPercent <= 0.0 || MaxRiskPercent > 10.0)
    {
        Print("Error: MaxRiskPercent must be between 0.0 and 10.0");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Display current open positions                                   |
//+------------------------------------------------------------------+
void DisplayCurrentPositions()
{
    Print("--- Current Open Positions ---");

    int total = OrdersTotal();
    int buyCount = 0;
    int sellCount = 0;
    double buyVolume = 0.0;
    double sellVolume = 0.0;

    for(int i = 0; i < total; i++)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;

        if(OrderType() == OP_BUY)
        {
            buyCount++;
            buyVolume += OrderLots();
        }
        else if(OrderType() == OP_SELL)
        {
            sellCount++;
            sellVolume += OrderLots();
        }

        Print(StringFormat("Ticket: %d | %s | %s | %.2f lots | Profit: %.2f",
                           OrderTicket(),
                           OrderSymbol(),
                           OrderType() == OP_BUY ? "BUY" : "SELL",
                           OrderLots(),
                           OrderProfit()));
    }

    Print(StringFormat("Total: %d BUY (%.2f lots), %d SELL (%.2f lots)",
                       buyCount, buyVolume, sellCount, sellVolume));
    Print("------------------------------");
}

//+------------------------------------------------------------------+
//| Execute full hedge for all positions                            |
//+------------------------------------------------------------------+
void ExecuteFullHedge()
{
    Print("Executing full hedge for all positions...");

    int total = OrdersTotal();
    hedgeCount = 0;
    totalHedgedVolume = 0.0;

    for(int i = 0; i < total; i++)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;

        if(OrderType() != OP_BUY && OrderType() != OP_SELL)
            continue;

        // Hedge this position
        if(HedgeSinglePosition(OrderTicket()))
        {
            hedgeCount++;
        }
    }
}

//+------------------------------------------------------------------+
//| Execute hedge for specific symbol                               |
//+------------------------------------------------------------------+
void ExecuteSymbolHedge()
{
    string targetSymbol = SpecificSymbol;

    if(StringLen(targetSymbol) == 0)
        targetSymbol = Symbol();

    Print("Executing hedge for symbol: ", targetSymbol);

    int total = OrdersTotal();
    hedgeCount = 0;
    totalHedgedVolume = 0.0;

    for(int i = 0; i < total; i++)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;

        if(OrderSymbol() != targetSymbol)
            continue;

        if(OrderType() != OP_BUY && OrderType() != OP_SELL)
            continue;

        // Hedge this position
        if(HedgeSinglePosition(OrderTicket()))
        {
            hedgeCount++;
        }
    }
}

//+------------------------------------------------------------------+
//| Execute emergency hedge for all positions immediately           |
//+------------------------------------------------------------------+
void ExecuteEmergencyHedge()
{
    Print("!!! EMERGENCY HEDGE ACTIVATED !!!");

    Alert("EMERGENCY HEDGE: Hedging all positions NOW!");

    int total = OrdersTotal();
    hedgeCount = 0;
    totalHedgedVolume = 0.0;

    // Calculate total exposure
    double totalBuyLots = 0.0;
    double totalSellLots = 0.0;

    for(int i = 0; i < total; i++)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;

        if(OrderType() == OP_BUY)
            totalBuyLots += OrderLots();
        else if(OrderType() == OP_SELL)
            totalSellLots += OrderLots();
    }

    Print(StringFormat("Total Exposure - BUY: %.2f lots, SELL: %.2f lots",
                       totalBuyLots, totalSellLots));

    // Hedge each position with emergency priority
    for(int i = 0; i < total; i++)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;

        if(OrderType() != OP_BUY && OrderType() != OP_SELL)
            continue;

        // Emergency hedge (full ratio, no balance check)
        if(HedgeSinglePosition(OrderTicket(), true))
        {
            hedgeCount++;
        }
    }

    lastHedgeTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Hedge a single position                                         |
//+------------------------------------------------------------------+
bool HedgeSinglePosition(int originalTicket, bool emergency = false)
{
    if(!OrderSelect(originalTicket, SELECT_BY_TICKET))
    {
        Print("Error: Cannot select order ", originalTicket);
        return false;
    }

    string symbol = OrderSymbol();
    int orderType = OrderType();
    double originalLots = OrderLots();

    // Calculate hedge lots
    double hedgeLots = CalculateHedgeLots(originalLots, symbol, emergency);

    if(hedgeLots < MinLotSize)
    {
        Print("Warning: Hedge lots too small for ticket ", originalTicket);
        return false;
    }

    // Determine opposite order type
    int hedgeType = (orderType == OP_BUY) ? OP_SELL : OP_BUY;

    // Get current price
    double price;
    if(hedgeType == OP_BUY)
        price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    else
        price = SymbolInfoDouble(symbol, SYMBOL_BID);

    // Prepare hedge comment
    string comment = StringFormat("Hedge_%d", originalTicket);

    Print(StringFormat("Opening hedge: %s %s %.2f lots @ %.5f",
                       symbol,
                       hedgeType == OP_BUY ? "BUY" : "SELL",
                       hedgeLots,
                       price));

    // Open hedge position
    int hedgeTicket = OrderSend(symbol,
                                 hedgeType,
                                 hedgeLots,
                                 price,
                                 Slippage,
                                 0, // No SL
                                 0, // No TP
                                 comment,
                                 0,
                                 0,
                                 hedgeType == OP_BUY ? BuyHedgeColor : SellHedgeColor);

    if(hedgeTicket < 0)
    {
        int error = GetLastError();
        Print("Error opening hedge: ", error, " - ", ErrorDescription(error));
        return false;
    }

    Print("Hedge opened successfully. Ticket: ", hedgeTicket);

    totalHedgedVolume += hedgeLots;

    // Draw hedge marker on chart
    if(ShowHedgeInfo)
    {
        DrawHedgeMarker(hedgeTicket, price, hedgeType);
    }

    return true;
}

//+------------------------------------------------------------------+
//| Calculate hedge lot size                                        |
//+------------------------------------------------------------------+
double CalculateHedgeLots(double originalLots, string symbol, bool emergency)
{
    double hedgeLots = originalLots * HedgeRatio;

    // Auto-adjust for balance protection
    if(UseBalanceProtection && !emergency)
    {
        double balance = AccountBalance();
        double maxRiskAmount = balance * MaxRiskPercent / 100.0;

        // Calculate position value
        double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

        if(tickValue > 0 && tickSize > 0)
        {
            double positionValue = hedgeLots * tickValue / tickSize;

            // Limit by max risk
            if(positionValue > maxRiskAmount)
            {
                hedgeLots = maxRiskAmount * tickSize / tickValue;
                Print("Warning: Hedge lots reduced for balance protection");
            }
        }
    }

    // Normalize lot size
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    if(lotStep > 0)
        hedgeLots = MathFloor(hedgeLots / lotStep) * lotStep;

    // Apply min/max limits
    hedgeLots = MathMax(MinLotSize, MathMin(MaxLotSize, hedgeLots));

    return hedgeLots;
}

//+------------------------------------------------------------------+
//| Draw hedge marker on chart                                      |
//+------------------------------------------------------------------+
void DrawHedgeMarker(int ticket, double price, int type)
{
    string objName = scriptName + "_Hedge_" + IntegerToString(ticket);

    if(ObjectFind(0, objName) >= 0)
        ObjectDelete(0, objName);

    ObjectCreate(0, objName, OBJ_ARROW, 0, TimeCurrent(), price);
    ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, type == OP_BUY ? 233 : 234);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, type == OP_BUY ? BuyHedgeColor : SellHedgeColor);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
    ObjectSetString(0, objName, OBJPROP_TEXT, "Hedge " + IntegerToString(ticket));
}

//+------------------------------------------------------------------+
//| Display hedge results                                           |
//+------------------------------------------------------------------+
void DisplayHedgeResults()
{
    Print("--- Hedge Results ---");
    Print("Positions hedged: ", hedgeCount);
    Print("Total hedged volume: ", DoubleToString(totalHedgedVolume, 2), " lots");
    Print("Account balance: ", DoubleToString(AccountBalance(), 2));
    Print("Account equity: ", DoubleToString(AccountEquity(), 2));
    Print("Free margin: ", DoubleToString(AccountFreeMargin(), 2));
    Print("---------------------");

    if(ShowHedgeInfo)
    {
        DisplayHedgeInfoPanel();
    }
}

//+------------------------------------------------------------------+
//| Display hedge information panel on chart                        |
//+------------------------------------------------------------------+
void DisplayHedgeInfoPanel()
{
    string objName = scriptName + "_InfoPanel";

    if(ObjectFind(0, objName) >= 0)
        ObjectDelete(0, objName);

    ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 50);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 9);
    ObjectSetString(0, objName, OBJPROP_FONT, "Courier New");
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clrYellow);

    string infoText = StringFormat("QuickHedge: %d hedges | %.2f lots | %.2f%%",
                                    hedgeCount,
                                    totalHedgedVolume,
                                    (AccountEquity() / AccountBalance() - 1.0) * 100);

    ObjectSetString(0, objName, OBJPROP_TEXT, infoText);
}

//+------------------------------------------------------------------+
//| Create emergency hedge button                                   |
//+------------------------------------------------------------------+
void CreateEmergencyButton()
{
    string objName = scriptName + "_EmergencyBtn";

    if(ObjectFind(0, objName) >= 0)
        ObjectDelete(0, objName);

    ObjectCreate(0, objName, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 10);
    ObjectSetInteger(0, objName, OBJPROP_XSIZE, 150);
    ObjectSetInteger(0, objName, OBJPROP_YSIZE, 40);
    ObjectSetString(0, objName, OBJPROP_TEXT, "EMERGENCY HEDGE");
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, clrRed);
    ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, clrDarkRed);

    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Remove emergency button                                         |
//+------------------------------------------------------------------+
void RemoveEmergencyButton()
{
    string objName = scriptName + "_EmergencyBtn";

    if(ObjectFind(0, objName) >= 0)
        ObjectDelete(0, objName);

    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Check for emergency hedge conditions (EA mode)                  |
//+------------------------------------------------------------------+
void CheckEmergencyConditions()
{
    // Check if emergency hedge is needed based on equity drawdown
    double balance = AccountBalance();
    double equity = AccountEquity();

    if(balance <= 0) return;

    double drawdown = (balance - equity) / balance * 100.0;

    // Trigger emergency hedge if drawdown exceeds threshold
    double emergencyThreshold = MaxRiskPercent * 5.0; // 5x max risk

    if(drawdown > emergencyThreshold)
    {
        // Prevent multiple rapid hedges
        if(TimeCurrent() - lastHedgeTime > 60) // 1 minute cooldown
        {
            Print("Emergency condition detected! Drawdown: ", DoubleToString(drawdown, 2), "%");
            ExecuteEmergencyHedge();
        }
    }
}

//+------------------------------------------------------------------+
//| Get error description                                           |
//+------------------------------------------------------------------+
string ErrorDescription(int errorCode)
{
    switch(errorCode)
    {
        case 0:    return "No error";
        case 1:    return "No error but result is unknown";
        case 2:    return "Common error";
        case 3:    return "Invalid trade parameters";
        case 4:    return "Trade server is busy";
        case 5:    return "Old version of terminal";
        case 6:    return "No connection";
        case 7:    return "Not enough rights";
        case 8:    return "Too frequent requests";
        case 9:    return "Malfunctional trade operation";
        case 64:   return "Account disabled";
        case 65:   return "Invalid account";
        case 128:  return "Trade timeout";
        case 129:  return "Invalid price";
        case 130:  return "Invalid stops";
        case 131:  return "Invalid trade volume";
        case 132:  return "Market is closed";
        case 133:  return "Trade is disabled";
        case 134:  return "Not enough money";
        case 135:  return "Price changed";
        case 136:  return "Off quotes";
        case 137:  return "Broker is busy";
        case 138:  return "Requote";
        case 139:  return "Order is locked";
        case 140:  return "Long positions only";
        case 141:  return "Too many requests";
        case 145:  return "Modification denied";
        case 146:  return "Trade context is busy";
        case 147:  return "Expirations are denied";
        case 148:  return "Too many open orders";
        default:   return "Unknown error: " + IntegerToString(errorCode);
    }
}
//+------------------------------------------------------------------+
