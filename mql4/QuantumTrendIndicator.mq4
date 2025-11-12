//+------------------------------------------------------------------+
//|                                        QuantumTrendIndicator.mq4 |
//|                                  QuantumTrader-Pro ML Trading    |
//|                        Quantum Mechanics-Based Trend Indicator   |
//+------------------------------------------------------------------+
#property copyright "QuantumTrader-Pro"
#property link      "https://github.com/quantumtrader-pro"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 4

// Indicator properties
#property indicator_color1 clrLime        // Bullish zone
#property indicator_color2 clrRed         // Bearish zone
#property indicator_color3 clrDodgerBlue  // Quantum wave upper
#property indicator_color4 clrOrange      // Quantum wave lower
#property indicator_width1 2
#property indicator_width2 2
#property indicator_width3 1
#property indicator_width4 1

// Input parameters
input int      QuantumPeriod = 21;           // Quantum wave period
input int      ProbabilityPeriod = 14;       // Probability calculation period
input double   QuantumSensitivity = 1.5;     // Wave sensitivity (1.0-3.0)
input int      WaveDepth = 100;              // Historical wave depth
input bool     ShowProbability = true;        // Display probability scores
input bool     ShowZones = true;              // Show bullish/bearish zones
input color    BullishColor = clrLime;        // Bullish zone color
input color    BearishColor = clrRed;         // Bearish zone color
input int      TextSize = 10;                 // Probability text size

// Indicator buffers
double BullishZoneBuffer[];
double BearishZoneBuffer[];
double QuantumWaveUpper[];
double QuantumWaveLower[];

// Global variables
string indicatorName = "QuantumTrend";
datetime lastBarTime = 0;
double currentProbability = 0.0;
string currentTrend = "NEUTRAL";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    // Set indicator buffers
    SetIndexBuffer(0, BullishZoneBuffer);
    SetIndexBuffer(1, BearishZoneBuffer);
    SetIndexBuffer(2, QuantumWaveUpper);
    SetIndexBuffer(3, QuantumWaveLower);

    // Set indicator styles
    SetIndexStyle(0, DRAW_HISTOGRAM, STYLE_SOLID, 2, BullishColor);
    SetIndexStyle(1, DRAW_HISTOGRAM, STYLE_SOLID, 2, BearishColor);
    SetIndexStyle(2, DRAW_LINE, STYLE_SOLID, 1, clrDodgerBlue);
    SetIndexStyle(3, DRAW_LINE, STYLE_SOLID, 1, clrOrange);

    // Set indicator labels
    SetIndexLabel(0, "Bullish Zone");
    SetIndexLabel(1, "Bearish Zone");
    SetIndexLabel(2, "Quantum Wave Upper");
    SetIndexLabel(3, "Quantum Wave Lower");

    // Set indicator name
    IndicatorShortName(indicatorName + "(" + IntegerToString(QuantumPeriod) + ")");

    // Validate parameters
    if(QuantumPeriod < 5)
    {
        Print("Error: QuantumPeriod must be >= 5");
        return(INIT_PARAMETERS_INCORRECT);
    }

    if(ProbabilityPeriod < 5)
    {
        Print("Error: ProbabilityPeriod must be >= 5");
        return(INIT_PARAMETERS_INCORRECT);
    }

    if(QuantumSensitivity < 0.5 || QuantumSensitivity > 5.0)
    {
        Print("Warning: QuantumSensitivity should be between 0.5 and 5.0");
    }

    Print("QuantumTrendIndicator initialized successfully");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Remove all objects created by indicator
    RemoveIndicatorObjects();

    Print("QuantumTrendIndicator deinitialized. Reason: ", reason);
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
    int limit = rates_total - prev_calculated;

    // Calculate for new bars or on first run
    if(prev_calculated == 0)
        limit = rates_total - QuantumPeriod - 1;

    if(limit < 0) return(0);

    // Main calculation loop
    for(int i = limit; i >= 0; i--)
    {
        // Calculate quantum wave function
        double waveFunction = CalculateWaveFunction(i, close);

        // Calculate probability distribution
        double probability = CalculateProbability(i, close);

        // Calculate quantum uncertainty
        double uncertainty = CalculateUncertainty(i, high, low);

        // Determine trend zones
        double upperBand = waveFunction + (uncertainty * QuantumSensitivity);
        double lowerBand = waveFunction - (uncertainty * QuantumSensitivity);

        QuantumWaveUpper[i] = upperBand;
        QuantumWaveLower[i] = lowerBand;

        // Determine bullish/bearish zones
        if(close[i] > upperBand && probability > 0.6)
        {
            BullishZoneBuffer[i] = high[i] - low[i];
            BearishZoneBuffer[i] = 0;
        }
        else if(close[i] < lowerBand && probability < 0.4)
        {
            BullishZoneBuffer[i] = 0;
            BearishZoneBuffer[i] = high[i] - low[i];
        }
        else
        {
            BullishZoneBuffer[i] = 0;
            BearishZoneBuffer[i] = 0;
        }

        // Update current values for most recent bar
        if(i == 0)
        {
            currentProbability = probability;

            if(close[i] > upperBand && probability > 0.6)
                currentTrend = "BULLISH";
            else if(close[i] < lowerBand && probability < 0.4)
                currentTrend = "BEARISH";
            else
                currentTrend = "NEUTRAL";
        }
    }

    // Display probability information on new bar
    if(ShowProbability && time[0] != lastBarTime)
    {
        lastBarTime = time[0];
        DisplayProbabilityInfo();
    }

    return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate quantum wave function using Gaussian distribution      |
//+------------------------------------------------------------------+
double CalculateWaveFunction(int shift, const double &price[])
{
    double sum = 0.0;
    double weightSum = 0.0;

    for(int i = 0; i < QuantumPeriod; i++)
    {
        if(shift + i >= ArraySize(price)) break;

        // Gaussian weight: exp(-x^2 / (2*sigma^2))
        double x = (double)i / QuantumPeriod;
        double sigma = 0.3;
        double weight = MathExp(-(x * x) / (2 * sigma * sigma));

        sum += price[shift + i] * weight;
        weightSum += weight;
    }

    return weightSum > 0 ? sum / weightSum : price[shift];
}

//+------------------------------------------------------------------+
//| Calculate probability using wave function collapse               |
//+------------------------------------------------------------------+
double CalculateProbability(int shift, const double &price[])
{
    double bullishProb = 0.0;
    int bullCount = 0;

    for(int i = 0; i < ProbabilityPeriod; i++)
    {
        if(shift + i + 1 >= ArraySize(price)) break;

        // Count bullish bars (close > open)
        if(price[shift + i] > price[shift + i + 1])
        {
            bullCount++;
        }
    }

    bullishProb = (double)bullCount / ProbabilityPeriod;

    // Apply quantum superposition principle
    // Normalize to account for market uncertainty
    double normalizedProb = 0.5 + (bullishProb - 0.5) * 0.8;

    return MathMax(0.0, MathMin(1.0, normalizedProb));
}

//+------------------------------------------------------------------+
//| Calculate quantum uncertainty (Heisenberg-inspired)              |
//+------------------------------------------------------------------+
double CalculateUncertainty(int shift, const double &high[], const double &low[])
{
    double sumRange = 0.0;
    int count = 0;

    for(int i = 0; i < QuantumPeriod; i++)
    {
        if(shift + i >= ArraySize(high)) break;

        sumRange += high[shift + i] - low[shift + i];
        count++;
    }

    double avgRange = count > 0 ? sumRange / count : 0;

    // Apply uncertainty principle: ΔP * ΔX >= h/4π
    // Simplified: uncertainty increases with volatility
    return avgRange * MathSqrt(QuantumPeriod) / 10.0;
}

//+------------------------------------------------------------------+
//| Display probability information on chart                         |
//+------------------------------------------------------------------+
void DisplayProbabilityInfo()
{
    string objName = indicatorName + "_ProbText";

    // Remove old object
    if(ObjectFind(0, objName) >= 0)
        ObjectDelete(0, objName);

    if(!ShowProbability) return;

    // Create text object
    ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 30);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, TextSize);
    ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");

    // Set color based on trend
    color textColor = clrWhite;
    if(currentTrend == "BULLISH")
        textColor = BullishColor;
    else if(currentTrend == "BEARISH")
        textColor = BearishColor;

    ObjectSetInteger(0, objName, OBJPROP_COLOR, textColor);

    // Format probability text
    string probText = StringFormat("%s | Probability: %.1f%% | Trend: %s",
                                    indicatorName,
                                    currentProbability * 100,
                                    currentTrend);

    ObjectSetString(0, objName, OBJPROP_TEXT, probText);

    // Create zone indicators
    if(ShowZones)
    {
        DisplayZoneMarkers();
    }
}

//+------------------------------------------------------------------+
//| Display zone markers on chart                                    |
//+------------------------------------------------------------------+
void DisplayZoneMarkers()
{
    string zoneObj = indicatorName + "_Zone";

    if(ObjectFind(0, zoneObj) >= 0)
        ObjectDelete(0, zoneObj);

    if(currentTrend == "NEUTRAL") return;

    // Create rectangle for zone
    ObjectCreate(0, zoneObj, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, zoneObj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, zoneObj, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, zoneObj, OBJPROP_YDISTANCE, 50);
    ObjectSetInteger(0, zoneObj, OBJPROP_FONTSIZE, TextSize - 1);
    ObjectSetString(0, zoneObj, OBJPROP_FONT, "Arial");

    string zoneText = currentTrend == "BULLISH" ? "BULLISH ZONE" : "BEARISH ZONE";
    color zoneColor = currentTrend == "BULLISH" ? BullishColor : BearishColor;

    ObjectSetInteger(0, zoneObj, OBJPROP_COLOR, zoneColor);
    ObjectSetString(0, zoneObj, OBJPROP_TEXT, zoneText);
}

//+------------------------------------------------------------------+
//| Remove all indicator objects from chart                          |
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
//| Get current trend (for external EA access)                       |
//+------------------------------------------------------------------+
string GetCurrentTrend()
{
    return currentTrend;
}

//+------------------------------------------------------------------+
//| Get current probability (for external EA access)                 |
//+------------------------------------------------------------------+
double GetCurrentProbability()
{
    return currentProbability;
}
//+------------------------------------------------------------------+
