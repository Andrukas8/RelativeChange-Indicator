/*
Copyright (C) 2021 Mateus Matucuma Teixeira

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
*/
#ifndef RELATIVECHANGE_H
#define RELATIVECHANGE_H
//+------------------------------------------------------------------+
//|                                              Relative Change.mq5 |
//|                     Copyright (C) 2021, Mateus Matucuma Teixeira |
//|                                            mateusmtoss@gmail.com |
//| GNU General Public License version 2 - GPL-2.0                   |
//| https://opensource.org/licenses/gpl-2.0.php                      |
//+------------------------------------------------------------------+
// https://github.com/BRMateus2/RelativeChange-Indicator/
//---- Main Properties
#property copyright "2021, Mateus Matucuma Teixeira"
#property link "https://github.com/BRMateus2/RelativeChange-Indicator/"
#property description "This Indicator will show the Change Percentage of a given Moving Average period.\n"
#property description "The indicator can be used to observe volatility and the force of past swings, useful to determine excesses that will possibly be reversed or repeated, given that the user has knowledge to complement with volume or standard-deviation strategies.\n"
#property description "It is suggested a period of 27600 at M1 or 1200 at H1 (meaning 40 sessions of 23hs each), or any period that complements your strategy."
#property version "1.01"
#property strict
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots 3
//---- Definitions
#ifndef ErrorPrint
#define ErrorPrint(Dp_error) Print("ERROR: " + Dp_error + " at \"" + __FUNCTION__ + ":" + IntegerToString(__LINE__) + "\", last internal error: " + IntegerToString(GetLastError()) + " (" + __FILE__ + ")"); ResetLastError(); DebugBreak(); // It should be noted that the GetLastError() function doesn't zero the _LastError variable. Usually the ResetLastError() function is called before calling a function, after which an error appearance is checked.
#endif
//#define INPUT const
#ifndef INPUT
#define INPUT input
#endif
//---- Input Parameters
//---- "Basic Settings"
input group "Basic Settings"
string iName; // Defined at OnInit()
const int iDigits = 2; // Subdigits on data
INPUT int maPeriodInp = 1200; // Moving Average (MA) of last N candles
int maPeriod = 60; // Backup maPeriod if user inserts wrong value
const int maPeriodShift = 0; // Shift data
INPUT bool iBufHLVisible = true; // High and Low Line Change Visible
INPUT bool iBufCVisible = true; // Price Line Change/Close Visible
//INPUT ENUM_APPLIED_VOLUME ENUM_APPLIED_VOLUMEInp = VOLUME_TICK; // Volume by "Ticks" or by "Real"
INPUT ENUM_APPLIED_PRICE ENUM_APPLIED_PRICEInp = PRICE_CLOSE; // Applied Price Equation
INPUT ENUM_MA_METHOD ENUM_MA_METHODInp = MODE_SMA; // Applied Moving Average Method
INPUT bool relativeTowardsMA = true; // True = change is relative towards MA, False = from MA to Price
//---- "Adaptive Period"
input group "Adaptive Period"
INPUT bool maAdPeriodInp = true; // Adapt the Period? Overrides Standard Period Settings
INPUT int maAdPeriodMinutesInp = 27600; // Period in minutes that all M and H timeframes should adapt to?
INPUT int maAdPeriodD1Inp = 20; // Period for D1 - Daily Timeframe
INPUT int maAdPeriodW1Inp = 4; // Period for W1 - Weekly Timeframe
INPUT int maAdPeriodMN1Inp = 1; // Period for MN - Monthly Timeframe
//---- Indicator Indexes, Buffers and Handlers
int maHandle = 0;
const int maBufIndex = 3;
double maBuf[];
const int iBufHIndex = 0;
double iBufH[];
const int iBufLIndex = 1;
double iBufL[];
const int iBufCIndex = 2;
double iBufC[];
//---- Plot Definitions
input group "Plot Definitions";
// iBufH
input group "Relative High Change";
const string iBufHLabel = "Relative High Change";
INPUT color iBufHColor = clrRed; // Drawing Color
const ENUM_DRAW_TYPE iBufHDraw = DRAW_LINE; // Drawing Type
INPUT ENUM_LINE_STYLE iBufHStyle = STYLE_SOLID; // Drawing Style
INPUT int iBufHWidth = 1; // Drawing Width
// iBufL
input group "Relative Low Change";
const string iBufLLabel = "Relative Low Change";
INPUT color iBufLColor = clrSpringGreen; // Drawing Color
const ENUM_DRAW_TYPE iBufLDraw = DRAW_LINE; // Drawing Type
INPUT ENUM_LINE_STYLE iBufLStyle = STYLE_SOLID; // Drawing Style
INPUT int iBufLWidth = 1; // Drawing Width
// iBufC
input group "Relative Close Change";
const string iBufCLabel = "Relative Close Change";
INPUT color iBufCColor = clrMoccasin; // Drawing Color
const ENUM_DRAW_TYPE iBufCDraw = DRAW_LINE; // Drawing Type
INPUT ENUM_LINE_STYLE iBufCStyle = STYLE_SOLID; // Drawing Style
INPUT int iBufCWidth = 1; // Drawing Width
// Level Zero Axis
input group "Level Zero Axis";
INPUT bool iShowZero = true; // Show Zero Axis
INPUT color iShowZeroColor = clrMoccasin; // Drawing Color
const ENUM_DRAW_TYPE iShowZeroDraw = DRAW_LINE; // Drawing Type
INPUT ENUM_LINE_STYLE iShowZeroStyle = STYLE_SOLID; // Drawing Style
INPUT int iShowZeroWidth = 1; // Drawing Width
//---- PlotIndexSetString() Timer optimization, updates once per second
datetime last = 0;
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// Constructor or initialization function
// https://www.mql5.com/en/docs/basis/function/events
// https://www.mql5.com/en/articles/100
//+------------------------------------------------------------------+
int OnInit()
{
// User and Developer Input scrutiny
    if(maAdPeriodInp == true) { // Calculate maPeriod if ma_period_adaptive_inp == true. Adaptation works flawless for less than D1 - D1, W1 and MN1 are a constant set by the user.
        if((PeriodSeconds(PERIOD_CURRENT) < PeriodSeconds(PERIOD_D1)) && (PeriodSeconds(PERIOD_CURRENT) >= PeriodSeconds(PERIOD_M1))) {
            if(maAdPeriodMinutesInp > 0) {
                int maPeriodCalc = ((maAdPeriodMinutesInp * 60) / PeriodSeconds(PERIOD_CURRENT));
                if(maPeriodCalc == 0) { // If the division is less than 1, then we have to complement to a minimum, user can also hide on timeframes that are not needed.
                    maPeriod = maPeriodCalc + 1;
                } else if(maPeriodCalc < 0) {
                    ErrorPrint("calculation error with \"maPeriodCalc = ((maAdPeriodMinutesInp * 60) / PeriodSeconds(PERIOD_CURRENT))\". Indicator will use value \"" + IntegerToString(maPeriod) + "\" for calculations."); // maPeriod is already defined
                } else { // If maPeriodCalc is not zero, neither negative, them it is valid.
                    maPeriod = maPeriodCalc;
                }
            } else {
                ErrorPrint("wrong value for \"maAdPeriodMinutesInp\" = \"" + IntegerToString(maAdPeriodMinutesInp) + "\". Indicator will use value \"" + IntegerToString(maPeriod) + "\" for calculations."); // maPeriod is already defined
            }
        } else if(PeriodSeconds(PERIOD_CURRENT) == PeriodSeconds(PERIOD_D1)) {
            if(maAdPeriodD1Inp > 0) {
                maPeriod = maAdPeriodD1Inp;
            } else {
                ErrorPrint("wrong value for \"maAdPeriodD1Inp\" = \"" + IntegerToString(maAdPeriodD1Inp) + "\". Indicator will use value \"" + IntegerToString(maPeriod) + "\" for calculations."); // maPeriod is already defined
            }
        } else if(PeriodSeconds(PERIOD_CURRENT) == PeriodSeconds(PERIOD_W1)) {
            if(maAdPeriodW1Inp > 0) {
                maPeriod = maAdPeriodW1Inp;
            } else {
                ErrorPrint("wrong value for \"maAdPeriodW1Inp\" = \"" + IntegerToString(maAdPeriodW1Inp) + "\". Indicator will use value \"" + IntegerToString(maPeriod) + "\" for calculations."); // maPeriod is already defined
            }
        } else if(PeriodSeconds(PERIOD_CURRENT) == PeriodSeconds(PERIOD_MN1)) {
            if(maAdPeriodMN1Inp > 0) {
                maPeriod = maAdPeriodMN1Inp;
            } else {
                ErrorPrint("wrong value for \"maAdPeriodMN1Inp\" = \"" + IntegerToString(maAdPeriodMN1Inp) + "\". Indicator will use value \"" + IntegerToString(maPeriod) + "\" for calculations."); // maPeriod is already defined
            }
        } else {
            ErrorPrint("untreated condition. Indicator will use value \"" + IntegerToString(maPeriod) + "\" for calculations."); // maPeriod is already defined
        }
    } else if(maPeriodInp <= 0 && maAdPeriodInp == false) {
        ErrorPrint("wrong value for \"maPeriodInp\" = \"" + IntegerToString(maPeriodInp) + "\". Indicator will use value \"" + IntegerToString(maPeriod) + "\" for calculations."); // maPeriod is already defined
    } else {
        maPeriod = maPeriodInp;
    }
// Treat Indicator
    if(!IndicatorSetInteger(INDICATOR_DIGITS, iDigits)) { // Indicator subdigit precision
        ErrorPrint("!IndicatorSetInteger(INDICATOR_DIGITS, iDigits)");
        return INIT_FAILED;
    }
// Set Levels
    if(iShowZero) {
        if(!IndicatorSetInteger(INDICATOR_LEVELS, 1)) {
            ErrorPrint("!IndicatorSetInteger(INDICATOR_LEVELS, 1)");
            return INIT_FAILED;
        }
        if(!IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0)) {
            ErrorPrint("!IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0)");
            return INIT_FAILED;
        }
        if(!IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, iShowZeroColor)) {
            ErrorPrint("!IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, iShowZeroColor)");
            return INIT_FAILED;
        }
        if(!IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, iShowZeroStyle)) {
            ErrorPrint("!IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, iShowZeroStyle)");
            return INIT_FAILED;
        }
        if(!IndicatorSetInteger(INDICATOR_LEVELWIDTH, 0, iShowZeroWidth)) {
            ErrorPrint("!IndicatorSetInteger(INDICATOR_LEVELWIDTH, 0, iShowZeroWidth)");
            return INIT_FAILED;
        }
    } else {
        if(!IndicatorSetInteger(INDICATOR_LEVELS, 0)) {
            ErrorPrint("!IndicatorSetInteger(INDICATOR_LEVELS, 0)");
            return INIT_FAILED;
        }
    }
// Treat maHandle
    maHandle = iMA(Symbol(), Period(), maPeriod, maPeriodShift, ENUM_MA_METHODInp, ENUM_APPLIED_PRICEInp);
    if(maHandle == INVALID_HANDLE || maHandle < 0) {
        ErrorPrint("maHandle == INVALID_HANDLE || maHandle < 0");
        return INIT_FAILED;
    }
    if(!SetIndexBuffer(maBufIndex, maBuf, INDICATOR_CALCULATIONS)) {
        ErrorPrint("!SetIndexBuffer(maBufIndex, maBuf, INDICATOR_CALCULATIONS)");
        return INIT_FAILED;
    }
// Treat iBufH, iBufL and iBufC
    if(!PlotIndexConstruct(iBufHIndex, iBufHLabel, iBufHColor, iBufH, INDICATOR_DATA, (iBufHLVisible ? iBufHDraw : DRAW_NONE), maPeriodShift, iBufHStyle, iBufHWidth, maPeriod, iBufHLVisible)) {
        ErrorPrint("");
        return INIT_FAILED;
    }
    if(!PlotIndexConstruct(iBufLIndex, iBufLLabel, iBufLColor, iBufL, INDICATOR_DATA, (iBufHLVisible ? iBufLDraw : DRAW_NONE), maPeriodShift, iBufLStyle, iBufLWidth, maPeriod, iBufHLVisible)) {
        ErrorPrint("");
        return INIT_FAILED;
    }
    if(!PlotIndexConstruct(iBufCIndex, iBufCLabel, iBufCColor, iBufC, INDICATOR_DATA, (iBufCVisible ? iBufCDraw : DRAW_NONE), maPeriodShift, iBufCStyle, iBufCWidth, maPeriod, iBufCVisible)) {
        ErrorPrint("");
        return INIT_FAILED;
    }
// Indicator Subwindow Short Name
    iName = StringFormat("RelChg(%d)", maPeriod); // Indicator name in Subwindow
    if(!IndicatorSetString(INDICATOR_SHORTNAME, iName)) { // Set Indicator name
        ErrorPrint("!IndicatorSetString(INDICATOR_SHORTNAME, iName)");
        return INIT_FAILED;
    }
    return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
// Calculation function
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime& time[],
                const double& open[],
                const double& high[],
                const double& low[],
                const double& close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[])
{
    if(rates_total < maPeriod) { // No need to calculate if the data is less than the requested period - it is returned as 0, because if we return rates_total, then the terminal interprets that the indicator has valid data
        return 0;
    } else if(BarsCalculated(maHandle) < rates_total) { // Indicator data is still not ready
        return 0;
    }
    if(CopyBuffer(maHandle, 0, 0, (rates_total - prev_calculated + 1), maBuf) <= 0) { // Try to copy, if there is no data copied for some reason, then we don't need to calculate - also, we don't need to copy rates before prev_calculated as they have the same result
        ErrorPrint("maHandle, 0, 0, (rates_total - prev_calculated + 1), maBuf) <= 0");
        return 0;
    }
    /*
        Math Function:
            On proposed Relative Change of a single candle, represents the Percentage of Change of that candle in relation to a defined Moving Average (MA), where:
                High Line is equal to High / MA.
                Low Line is equal to Low / MA.
                Close Line is equal to Close / MA.

            Since the first X candles are expected to be invalid, because there is no X < 0 data point, it will be skipped.
    */
// Main loop of calculations
    int i = (prev_calculated - 1);
    for(; i < rates_total && !IsStopped(); i++) {
        if(i < 0) {
            continue;
        }
        if(iBufHLVisible) {
            iBufH[i] = -(((relativeTowardsMA ? (maBuf[i] / high[i]) : (high[i] / maBuf[i])) * 100.0) - 100.0);
            iBufL[i] = -(((relativeTowardsMA ? (maBuf[i] / low[i]) : (low[i] / maBuf[i])) * 100.0) - 100.0);
        }
        if(iBufCVisible) {
            iBufC[i] = -(((relativeTowardsMA ? (maBuf[i] / close[i]) : (close[i] / maBuf[i])) * 100.0) - 100.0);
        }
    }
    if(i == rates_total && last < TimeCurrent()) {
        last = TimeCurrent();
        if(iBufHLVisible) {
            PlotIndexSetString(iBufHIndex, PLOT_LABEL, "Relative High Change (" + DoubleToString(iBufH[i - 1], 2) + "%)");
            PlotIndexSetString(iBufLIndex, PLOT_LABEL, "Relative Low Change (" + DoubleToString(iBufL[i - 1], 2) + "%)");
        }
        if(iBufCVisible) {
            PlotIndexSetString(iBufCIndex, PLOT_LABEL, "Relative Close Change (" + DoubleToString(iBufC[i - 1], 2) + "%)");
        }
    }
    return rates_total; // Calculations are done and valid
}
//+------------------------------------------------------------------+
// Destructor or Deinitialization function
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    return;
}
//+------------------------------------------------------------------+
// Extra functions, utilities and conversion
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Header Guard #endif
//+------------------------------------------------------------------+
#endif
//+------------------------------------------------------------------+
