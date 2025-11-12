//+------------------------------------------------------------------+
//|                                            MLSignalOverlay.mq4   |
//|                                  QuantumTrader-Pro ML Trading    |
//|                    Machine Learning Signal Overlay Indicator     |
//+------------------------------------------------------------------+
#property copyright "QuantumTrader-Pro"
#property link      "https://github.com/quantumtrader-pro"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 4

// Indicator properties
#property indicator_color1 clrLime        // Buy signals
#property indicator_color2 clrRed         // Sell signals
#property indicator_color3 clrDodgerBlue  // Exit long
#property indicator_color4 clrOrange      // Exit short

// Input parameters
input string   BridgeURL = "http://localhost:8080";  // Bridge server URL
input int      UpdateInterval = 5;                    // Update interval (seconds)
input bool     ShowArrows = true;                     // Display signal arrows
input bool     ShowConfidence = true;                 // Display confidence levels
input double   MinConfidence = 0.65;                  // Minimum confidence (0.0-1.0)
input int      SignalHistoryBars = 500;               // Signal history to display
input int      ArrowSize = 3;                         // Arrow size (1-5)
input bool     EnableAlerts = true;                   // Enable sound alerts
input bool     EnableNotifications = true;            // Enable push notifications
input color    BuyColor = clrLime;                    // Buy signal color
input color    SellColor = clrRed;                    // Sell signal color

// Arrow codes
#define ARROW_BUY 233       // Up arrow
#define ARROW_SELL 234      // Down arrow
#define ARROW_EXIT_LONG 251 // Small circle
#define ARROW_EXIT_SHORT 251

// Indicator buffers
double BuySignalBuffer[];
double SellSignalBuffer[];
double ExitLongBuffer[];
double ExitShortBuffer[];

// Global variables
string indicatorName = "MLSignals";
datetime lastUpdateTime = 0;
datetime lastSignalTime = 0;
int currentSignalCount = 0;

// Signal structure
struct MLSignal
{
    datetime timestamp;
    string direction;      // BUY, SELL, EXIT_LONG, EXIT_SHORT
    double confidence;
    double entryPrice;
    double stopLoss;
    double takeProfit;
    string reasoning;
    bool displayed;
};

MLSignal latestSignals[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    // Set indicator buffers
    SetIndexBuffer(0, BuySignalBuffer);
    SetIndexBuffer(1, SellSignalBuffer);
    SetIndexBuffer(2, ExitLongBuffer);
    SetIndexBuffer(3, ExitShortBuffer);

    // Set indicator styles
    SetIndexStyle(0, DRAW_ARROW, STYLE_SOLID, ArrowSize, BuyColor);
    SetIndexStyle(1, DRAW_ARROW, STYLE_SOLID, ArrowSize, SellColor);
    SetIndexStyle(2, DRAW_ARROW, STYLE_SOLID, ArrowSize - 1, clrDodgerBlue);
    SetIndexStyle(3, DRAW_ARROW, STYLE_SOLID, ArrowSize - 1, clrOrange);

    // Set arrow codes
    SetIndexArrow(0, ARROW_BUY);
    SetIndexArrow(1, ARROW_SELL);
    SetIndexArrow(2, ARROW_EXIT_LONG);
    SetIndexArrow(3, ARROW_EXIT_SHORT);

    // Set indicator labels
    SetIndexLabel(0, "Buy Signal");
    SetIndexLabel(1, "Sell Signal");
    SetIndexLabel(2, "Exit Long");
    SetIndexLabel(3, "Exit Short");

    // Set indicator name
    IndicatorShortName(indicatorName);

    // Initialize buffers with empty values
    SetIndexEmptyValue(0, 0.0);
    SetIndexEmptyValue(1, 0.0);
    SetIndexEmptyValue(2, 0.0);
    SetIndexEmptyValue(3, 0.0);

    // Validate parameters
    if(MinConfidence < 0.0 || MinConfidence > 1.0)
    {
        Print("Error: MinConfidence must be between 0.0 and 1.0");
        return(INIT_PARAMETERS_INCORRECT);
    }

    if(UpdateInterval < 1)
    {
        Print("Error: UpdateInterval must be >= 1 second");
        return(INIT_PARAMETERS_INCORRECT);
    }

    // Initialize signal array
    ArrayResize(latestSignals, 0);

    Print("MLSignalOverlay initialized successfully");
    Print("Bridge URL: ", BridgeURL);

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Remove all objects created by indicator
    RemoveIndicatorObjects();

    Print("MLSignalOverlay deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    // Check if it's time to update signals from bridge
    if(TimeCurrent() - lastUpdateTime >= UpdateInterval)
    {
        UpdateSignalsFromBridge();
        lastUpdateTime = TimeCurrent();
    }

    // Clear buffers
    for(int i = 0; i < rates_total; i++)
    {
        BuySignalBuffer[i] = 0.0;
        SellSignalBuffer[i] = 0.0;
        ExitLongBuffer[i] = 0.0;
        ExitShortBuffer[i] = 0.0;
    }

    // Display signals on chart
    if(ShowArrows)
    {
        DisplaySignalsOnChart(time, high, low);
    }

    // Display confidence levels
    if(ShowConfidence)
    {
        DisplayConfidenceLevels();
    }

    return(rates_total);
}

//+------------------------------------------------------------------+
//| Update signals from WebSocket bridge                             |
//+------------------------------------------------------------------+
void UpdateSignalsFromBridge()
{
    string url = BridgeURL + "/api/signals?symbol=" + Symbol() + "&timeframe=" + GetTimeframeString();
    string headers = "Content-Type: application/json\r\n";
    string result;
    char post[];
    char responseData[];
    string responseHeaders;

    // Send HTTP request to bridge
    int timeout = 5000; // 5 seconds timeout

    ResetLastError();
    int res = WebRequest("GET", url, headers, timeout, post, responseData, responseHeaders);

    if(res == -1)
    {
        int error = GetLastError();

        if(error == 4060)
        {
            Print("Error: WebRequest not allowed. Add '", BridgeURL, "' to allowed URLs in MetaTrader options.");
        }
        else
        {
            Print("WebRequest error: ", error, " - ", ErrorDescription(error));
        }

        return;
    }

    // Convert response to string
    result = CharArrayToString(responseData);

    if(StringLen(result) == 0)
    {
        Print("Warning: Empty response from bridge");
        return;
    }

    // Parse JSON response (simplified parsing)
    ParseSignalsFromJSON(result);
}

//+------------------------------------------------------------------+
//| Parse signals from JSON response                                 |
//+------------------------------------------------------------------+
void ParseSignalsFromJSON(string json)
{
    // This is a simplified JSON parser
    // In production, use a proper JSON parsing library

    // Example response format:
    // {"signals": [{"direction": "BUY", "confidence": 0.85, "price": 1.1234, ...}]}

    if(StringFind(json, "\"signals\"") < 0)
    {
        return;
    }

    // Extract signals array
    int signalStart = StringFind(json, "[");
    int signalEnd = StringFind(json, "]", signalStart);

    if(signalStart < 0 || signalEnd < 0)
    {
        return;
    }

    string signalsStr = StringSubstr(json, signalStart + 1, signalEnd - signalStart - 1);

    // Split by objects
    string signalObjects[];
    int objCount = SplitString(signalsStr, "},", signalObjects);

    ArrayResize(latestSignals, objCount);

    for(int i = 0; i < objCount; i++)
    {
        ParseSingleSignal(signalObjects[i], latestSignals[i]);
    }

    currentSignalCount = objCount;
}

//+------------------------------------------------------------------+
//| Parse single signal object                                       |
//+------------------------------------------------------------------+
void ParseSingleSignal(string signalStr, MLSignal &signal)
{
    // Extract direction
    signal.direction = ExtractJSONString(signalStr, "direction");

    // Extract confidence
    signal.confidence = ExtractJSONDouble(signalStr, "confidence");

    // Extract prices
    signal.entryPrice = ExtractJSONDouble(signalStr, "entryPrice");
    signal.stopLoss = ExtractJSONDouble(signalStr, "stopLoss");
    signal.takeProfit = ExtractJSONDouble(signalStr, "takeProfit");

    // Extract reasoning
    signal.reasoning = ExtractJSONString(signalStr, "reasoning");

    // Set timestamp
    signal.timestamp = TimeCurrent();
    signal.displayed = false;
}

//+------------------------------------------------------------------+
//| Display signals on chart with arrows                             |
//+------------------------------------------------------------------+
void DisplaySignalsOnChart(const datetime &time[], const double &high[], const double &low[])
{
    for(int i = 0; i < ArraySize(latestSignals); i++)
    {
        if(latestSignals[i].confidence < MinConfidence)
            continue;

        if(latestSignals[i].displayed)
            continue;

        // Find bar index for signal timestamp
        int barIndex = iBarShift(Symbol(), Period(), latestSignals[i].timestamp);

        if(barIndex < 0 || barIndex >= ArraySize(time))
            continue;

        // Display appropriate arrow
        if(latestSignals[i].direction == "BUY")
        {
            BuySignalBuffer[barIndex] = low[barIndex] - (5 * Point);
            CreateSignalLabel(barIndex, time[barIndex], low[barIndex], "BUY", latestSignals[i].confidence, BuyColor);

            if(EnableAlerts && i == 0)
                Alert("ML Signal: BUY ", Symbol(), " Confidence: ", DoubleToString(latestSignals[i].confidence * 100, 1), "%");
        }
        else if(latestSignals[i].direction == "SELL")
        {
            SellSignalBuffer[barIndex] = high[barIndex] + (5 * Point);
            CreateSignalLabel(barIndex, time[barIndex], high[barIndex], "SELL", latestSignals[i].confidence, SellColor);

            if(EnableAlerts && i == 0)
                Alert("ML Signal: SELL ", Symbol(), " Confidence: ", DoubleToString(latestSignals[i].confidence * 100, 1), "%");
        }
        else if(latestSignals[i].direction == "EXIT_LONG")
        {
            ExitLongBuffer[barIndex] = high[barIndex] + (3 * Point);
        }
        else if(latestSignals[i].direction == "EXIT_SHORT")
        {
            ExitShortBuffer[barIndex] = low[barIndex] - (3 * Point);
        }

        latestSignals[i].displayed = true;
    }
}

//+------------------------------------------------------------------+
//| Create signal label with confidence                              |
//+------------------------------------------------------------------+
void CreateSignalLabel(int barIndex, datetime time, double price, string direction, double confidence, color clr)
{
    string objName = indicatorName + "_Label_" + TimeToString(time);

    if(ObjectFind(0, objName) >= 0)
        ObjectDelete(0, objName);

    if(!ShowConfidence)
        return;

    ObjectCreate(0, objName, OBJ_TEXT, 0, time, price);
    ObjectSetString(0, objName, OBJPROP_TEXT, StringFormat("%s %.0f%%", direction, confidence * 100));
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
    ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Display confidence levels panel                                  |
//+------------------------------------------------------------------+
void DisplayConfidenceLevels()
{
    string objName = indicatorName + "_ConfPanel";

    if(ObjectFind(0, objName) >= 0)
        ObjectDelete(0, objName);

    if(currentSignalCount == 0 || !ShowConfidence)
        return;

    // Get latest signal
    MLSignal latest = latestSignals[0];

    ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 30);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
    ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");

    color textColor = latest.direction == "BUY" ? BuyColor : SellColor;
    ObjectSetInteger(0, objName, OBJPROP_COLOR, textColor);

    string confText = StringFormat("ML: %s | Conf: %.1f%%",
                                    latest.direction,
                                    latest.confidence * 100);

    ObjectSetString(0, objName, OBJPROP_TEXT, confText);
}

//+------------------------------------------------------------------+
//| Remove all indicator objects                                     |
//+------------------------------------------------------------------+
void RemoveIndicatorObjects()
{
    int total = ObjectsTotal(0, 0, -1);

    for(int i = total - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i, 0, -1);

        if(StringFind(objName, indicatorName) >= 0)
        {
            ObjectDelete(0, objName);
        }
    }

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Get timeframe as string                                          |
//+------------------------------------------------------------------+
string GetTimeframeString()
{
    switch(Period())
    {
        case PERIOD_M1:  return "M1";
        case PERIOD_M5:  return "M5";
        case PERIOD_M15: return "M15";
        case PERIOD_M30: return "M30";
        case PERIOD_H1:  return "H1";
        case PERIOD_H4:  return "H4";
        case PERIOD_D1:  return "D1";
        case PERIOD_W1:  return "W1";
        case PERIOD_MN1: return "MN1";
        default:         return "M15";
    }
}

//+------------------------------------------------------------------+
//| Extract string value from JSON                                   |
//+------------------------------------------------------------------+
string ExtractJSONString(string json, string key)
{
    string searchKey = "\"" + key + "\":\"";
    int start = StringFind(json, searchKey);

    if(start < 0)
        return "";

    start += StringLen(searchKey);
    int end = StringFind(json, "\"", start);

    if(end < 0)
        return "";

    return StringSubstr(json, start, end - start);
}

//+------------------------------------------------------------------+
//| Extract double value from JSON                                   |
//+------------------------------------------------------------------+
double ExtractJSONDouble(string json, string key)
{
    string searchKey = "\"" + key + "\":";
    int start = StringFind(json, searchKey);

    if(start < 0)
        return 0.0;

    start += StringLen(searchKey);
    int end = StringFind(json, ",", start);

    if(end < 0)
        end = StringFind(json, "}", start);

    if(end < 0)
        return 0.0;

    string value = StringSubstr(json, start, end - start);
    StringTrimLeft(value);
    StringTrimRight(value);

    return StringToDouble(value);
}

//+------------------------------------------------------------------+
//| Split string by delimiter                                        |
//+------------------------------------------------------------------+
int SplitString(string str, string delimiter, string &result[])
{
    ArrayResize(result, 0);

    if(StringLen(str) == 0)
        return 0;

    int pos = 0;
    int count = 0;

    while(true)
    {
        int nextPos = StringFind(str, delimiter, pos);

        if(nextPos < 0)
        {
            ArrayResize(result, count + 1);
            result[count] = StringSubstr(str, pos);
            count++;
            break;
        }

        ArrayResize(result, count + 1);
        result[count] = StringSubstr(str, pos, nextPos - pos);
        count++;
        pos = nextPos + StringLen(delimiter);
    }

    return count;
}

//+------------------------------------------------------------------+
//| Get error description                                            |
//+------------------------------------------------------------------+
string ErrorDescription(int errorCode)
{
    switch(errorCode)
    {
        case 4060: return "WebRequest not allowed";
        case 4014: return "System is busy";
        case 4000: return "No error";
        default:   return "Error code: " + IntegerToString(errorCode);
    }
}
//+------------------------------------------------------------------+
