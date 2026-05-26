#property strict
#property copyright "stayTRU"
#property link      ""
#property version   "1.10"
#property description "stayTRU Trend Continuation Framework - Version 1.1 Alert Only"

input bool   UseSessionFilter           = true;
input int    StartHour                  = 9;
input int    EndHour                    = 18;
input int    ServerToSASTOffsetHours    = 0;
input int    SwingLookback              = 3;
input int    TrendSwingCount            = 3;
input bool   H4RequireConfirmedPullbackSwing = true;
input double H4MinPullbackPips          = 10.0;
input double H4MinPullbackPipsGold      = 100.0;
input double MaxSpreadPips              = 3.0;
input double MaxSpreadPipsGold          = 50.0;
input double StopBufferPips             = 5.0;
input double StopBufferPipsGold         = 50.0;
input double MinRewardRisk              = 2.5;
input bool   EnablePopupAlert           = true;
input bool   EnablePushNotification     = true;
input bool   EnableEmailAlert           = false;
input bool   EnableSoundAlert           = true;
input string SoundFile                  = "alert.wav";
input bool   ScanOnlyCurrentChartSymbol = true;
input string SymbolsToScan              = "EURUSD,GBPUSD,USDJPY,USDCHF,AUDUSD,NZDUSD,USDCAD,XAUUSD";
input bool   ApplyCleanChartTheme       = true;
input color  BullishCandleColor         = clrLime;
input color  BearishCandleColor         = clrRed;
input color  ChartBackgroundColor       = clrBlack;
input color  ChartForegroundColor       = clrWhite;

string EA_NAME = "stayTRU Trend Continuation Framework";

struct TrendInfo
{
   int direction;
   string description;
   double latestHigh;
   double previousHigh;
   double latestLow;
   double previousLow;
   int latestHighShift;
   int latestLowShift;
};

struct PullbackInfo
{
   bool valid;
   string reason;
   double swingHigh;
   double swingLow;
   double protectedLevel;
};

struct LevelInfo
{
   bool valid;
   string reason;
   double triggerLevel;
   double marketPrice;
   double entry;
   double stopLoss;
   double takeProfit;
   double risk;
   double reward;
   double rewardRisk;
};

string   g_symbols[];
datetime g_lastBuyAlertTimes[];
datetime g_lastSellAlertTimes[];
datetime g_lastScannedCandleTimes[];

// Initializes the symbol list and alert state.
int OnInit()
{
   LoadSymbolsToScan();
   ApplyChartTheme();
   Print(EA_NAME, " v1.1 initialized. ALERT-ONLY mode. Symbols loaded: ", ArraySize(g_symbols));
   return(INIT_SUCCEEDED);
}

// Cleans up only EA-owned chart objects.
void OnDeinit(const int reason)
{
   Print(EA_NAME, " deinitialized. Reason: ", reason);
}

// Applies a clean candlestick chart theme for live charts and visual tester.
void ApplyChartTheme()
{
   if(!ApplyCleanChartTheme)
      return;

   ChartSetInteger(0, CHART_MODE, CHART_CANDLES);
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, ChartBackgroundColor);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, ChartForegroundColor);
   ChartSetInteger(0, CHART_COLOR_GRID, ChartBackgroundColor);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, BullishCandleColor);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, BearishCandleColor);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, BullishCandleColor);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, BearishCandleColor);
   ChartSetInteger(0, CHART_COLOR_CHART_LINE, BullishCandleColor);
   ChartSetInteger(0, CHART_COLOR_BID, ChartForegroundColor);
   ChartSetInteger(0, CHART_COLOR_ASK, clrTomato);
   ChartRedraw(0);
}

// Scans the active chart symbol or configured symbol list on each tick.
void OnTick()
{
   if(UseSessionFilter && !IsWithinTradingSession())
      return;

   if(ScanOnlyCurrentChartSymbol)
      ScanSymbol(Symbol());
   else
   {
      for(int i = 0; i < ArraySize(g_symbols); i++)
         ScanSymbol(g_symbols[i]);
   }
}

// Loads and normalizes symbols from inputs.
void LoadSymbolsToScan()
{
   if(ScanOnlyCurrentChartSymbol)
   {
      ArrayResize(g_symbols, 1);
      g_symbols[0] = Symbol();
   }
   else
   {
      string parts[];
      ushort comma = StringGetCharacter(",", 0);
      int count = StringSplit(SymbolsToScan, comma, parts);
      ArrayResize(g_symbols, 0);

      for(int i = 0; i < count; i++)
      {
         string item = TrimString(parts[i]);
         if(item == "")
         continue;

         int size = ArraySize(g_symbols);
         ArrayResize(g_symbols, size + 1);
         g_symbols[size] = ResolveBrokerSymbol(item);
      }
   }

   ArrayResize(g_lastBuyAlertTimes, ArraySize(g_symbols));
   ArrayResize(g_lastSellAlertTimes, ArraySize(g_symbols));
   ArrayResize(g_lastScannedCandleTimes, ArraySize(g_symbols));
   for(int j = 0; j < ArraySize(g_symbols); j++)
   {
      g_lastBuyAlertTimes[j] = 0;
      g_lastSellAlertTimes[j] = 0;
      g_lastScannedCandleTimes[j] = 0;
   }
}

// Main per-symbol scanner.
void ScanSymbol(string symbol)
{
   symbol = TrimString(symbol);
   if(symbol == "")
      return;

   if(!SymbolSelect(symbol, true))
   {
      LogSetupStatus(symbol, "INIT", "REJECTED", "Symbol could not be selected in Market Watch.");
      return;
   }

   int entryTf = GetEntryTimeframe(symbol);
   datetime entryCandleTime = iTime(symbol, entryTf, 0);
   if(entryCandleTime <= 0)
   {
      LogSetupStatus(symbol, "INIT", "REJECTED", "No entry timeframe data available.");
      return;
   }

   if(!ShouldScanNewCandle(symbol, entryCandleTime))
      return;

   double spread = GetSpreadPips(symbol);
   double allowedSpread = IsGoldSymbol(symbol) ? MaxSpreadPipsGold : MaxSpreadPips;
   if(spread > allowedSpread)
   {
      LogSetupStatus(symbol, "SPREAD", "REJECTED", "Spread " + DoubleToString(spread, 1) + " pips exceeds allowed " + DoubleToString(allowedSpread, 1));
      return;
   }

   TrendInfo trend;
   GetDailyTrend(symbol, trend);
   LogSetupStatus(symbol, "DAILY", trend.description, "Entry timeframe: " + TimeframeToString(entryTf) + " | Spread: " + DoubleToString(spread, 1));

   if(trend.direction == 0)
   {
      LogSetupStatus(symbol, "TREND", "REJECTED", "Daily structure is unclear.");
      return;
   }

   PullbackInfo pullback;
   ValidateH4Pullback(symbol, trend, pullback);
   LogSetupStatus(symbol, "H4", pullback.valid ? "VALID" : "REJECTED", pullback.reason);

   if(!pullback.valid)
      return;

   if(trend.direction > 0)
      ProcessBuySetup(symbol, entryTf, entryCandleTime, trend, pullback);
   else
      ProcessSellSetup(symbol, entryTf, entryCandleTime, trend, pullback);
}

// Processes a bullish continuation setup.
void ProcessBuySetup(string symbol, int entryTf, datetime candleTime, TrendInfo &trend, PullbackInfo &pullback)
{
   double breakLevel = 0.0;
   string reason = "";

   if(!DetectBullishStructureBreak(symbol, entryTf, breakLevel, reason))
   {
      LogSetupStatus(symbol, "ENTRY BUY", "REJECTED", reason);
      return;
   }

   LevelInfo levels;
   double marketPrice = GetAlertMarketPrice(symbol, OP_BUY);
   CalculateSuggestedLevels(symbol, OP_BUY, breakLevel, marketPrice, pullback.swingLow, levels);
   if(!levels.valid)
   {
      LogSetupStatus(symbol, "LEVELS BUY", "REJECTED", levels.reason);
      return;
   }

   if(!CanSendAlert(symbol, OP_BUY, candleTime))
   {
      LogSetupStatus(symbol, "ALERT BUY", "SKIPPED", "Current entry timeframe candle already alerted.");
      return;
   }

   SendSetupAlert(symbol, "BUY", "Bullish", TimeframeToString(entryTf), levels);
   DrawSetupObjects(symbol, entryTf, "BUY", candleTime, levels);
   SetLastAlertTime(symbol, OP_BUY, candleTime);
   LogSetupStatus(symbol, "ALERT BUY", "SENT", "Structure break above " + DoubleToString(breakLevel, DigitsForSymbol(symbol)));
}

// Processes a bearish continuation setup.
void ProcessSellSetup(string symbol, int entryTf, datetime candleTime, TrendInfo &trend, PullbackInfo &pullback)
{
   double breakLevel = 0.0;
   string reason = "";

   if(!DetectBearishStructureBreak(symbol, entryTf, breakLevel, reason))
   {
      LogSetupStatus(symbol, "ENTRY SELL", "REJECTED", reason);
      return;
   }

   LevelInfo levels;
   double marketPrice = GetAlertMarketPrice(symbol, OP_SELL);
   CalculateSuggestedLevels(symbol, OP_SELL, breakLevel, marketPrice, pullback.swingHigh, levels);
   if(!levels.valid)
   {
      LogSetupStatus(symbol, "LEVELS SELL", "REJECTED", levels.reason);
      return;
   }

   if(!CanSendAlert(symbol, OP_SELL, candleTime))
   {
      LogSetupStatus(symbol, "ALERT SELL", "SKIPPED", "Current entry timeframe candle already alerted.");
      return;
   }

   SendSetupAlert(symbol, "SELL", "Bearish", TimeframeToString(entryTf), levels);
   DrawSetupObjects(symbol, entryTf, "SELL", candleTime, levels);
   SetLastAlertTime(symbol, OP_SELL, candleTime);
   LogSetupStatus(symbol, "ALERT SELL", "SENT", "Structure break below " + DoubleToString(breakLevel, DigitsForSymbol(symbol)));
}

// Checks the configured SAST trading session using a broker-server offset.
bool IsWithinTradingSession()
{
   datetime sastTime = TimeCurrent() + (ServerToSASTOffsetHours * 3600);
   int hour = TimeHour(sastTime);

   if(StartHour == EndHour)
      return(true);

   if(StartHour < EndHour)
      return(hour >= StartHour && hour < EndHour);

   return(hour >= StartHour || hour < EndHour);
}

// Fast symbols confirm on M15; slow symbols confirm on H1.
bool IsFastSymbol(string symbol)
{
   string base = StripSymbolSuffix(symbol);
   return(base == "EURUSD" || base == "USDJPY" || base == "USDCHF" || base == "AUDUSD");
}

// Returns the entry confirmation timeframe for the symbol.
int GetEntryTimeframe(string symbol)
{
   if(IsFastSymbol(symbol))
      return(PERIOD_M15);
   return(PERIOD_H1);
}

// Returns current spread in pip units.
double GetSpreadPips(string symbol)
{
   double point = MarketInfo(symbol, MODE_POINT);
   double pip = PipSize(symbol);
   double spreadPoints = MarketInfo(symbol, MODE_SPREAD);
   return((spreadPoints * point) / pip);
}

// Detects confirmed swing highs.
bool IsSwingHigh(string symbol, int timeframe, int shift)
{
   if(shift < SwingLookback + 1)
      return(false);

   double center = iHigh(symbol, timeframe, shift);
   if(center <= 0.0)
      return(false);

   for(int i = 1; i <= SwingLookback; i++)
   {
      if(iHigh(symbol, timeframe, shift - i) >= center)
         return(false);
      if(iHigh(symbol, timeframe, shift + i) >= center)
         return(false);
   }
   return(true);
}

// Detects confirmed swing lows.
bool IsSwingLow(string symbol, int timeframe, int shift)
{
   if(shift < SwingLookback + 1)
      return(false);

   double center = iLow(symbol, timeframe, shift);
   if(center <= 0.0)
      return(false);

   for(int i = 1; i <= SwingLookback; i++)
   {
      if(iLow(symbol, timeframe, shift - i) <= center)
         return(false);
      if(iLow(symbol, timeframe, shift + i) <= center)
         return(false);
   }
   return(true);
}

// Gets recent confirmed swing highs, newest first.
int GetRecentSwingHighs(string symbol, int timeframe, int needed, double &values[], int &shifts[])
{
   ArrayResize(values, needed);
   ArrayResize(shifts, needed);

   int found = 0;
   int bars = iBars(symbol, timeframe);
   int maxShift = MathMin(bars - SwingLookback - 1, 500);

   for(int shift = SwingLookback + 1; shift <= maxShift && found < needed; shift++)
   {
      if(IsSwingHigh(symbol, timeframe, shift))
      {
         values[found] = iHigh(symbol, timeframe, shift);
         shifts[found] = shift;
         found++;
      }
   }
   return(found);
}

// Gets recent confirmed swing lows, newest first.
int GetRecentSwingLows(string symbol, int timeframe, int needed, double &values[], int &shifts[])
{
   ArrayResize(values, needed);
   ArrayResize(shifts, needed);

   int found = 0;
   int bars = iBars(symbol, timeframe);
   int maxShift = MathMin(bars - SwingLookback - 1, 500);

   for(int shift = SwingLookback + 1; shift <= maxShift && found < needed; shift++)
   {
      if(IsSwingLow(symbol, timeframe, shift))
      {
         values[found] = iLow(symbol, timeframe, shift);
         shifts[found] = shift;
         found++;
      }
   }
   return(found);
}

// Determines Daily market-structure trend.
void GetDailyTrend(string symbol, TrendInfo &trend)
{
   trend.direction = 0;
   trend.description = "Unclear";
   trend.latestHigh = 0.0;
   trend.previousHigh = 0.0;
   trend.latestLow = 0.0;
   trend.previousLow = 0.0;
   trend.latestHighShift = 0;
   trend.latestLowShift = 0;

   int needed = MathMax(TrendSwingCount, 2);
   double highs[];
   double lows[];
   int highShifts[];
   int lowShifts[];

   int highCount = GetRecentSwingHighs(symbol, PERIOD_D1, needed, highs, highShifts);
   int lowCount = GetRecentSwingLows(symbol, PERIOD_D1, needed, lows, lowShifts);

   if(highCount < needed || lowCount < needed)
   {
      trend.description = "Unclear - not enough confirmed Daily swings.";
      return;
   }

   bool bullish = true;
   bool bearish = true;
   for(int i = 0; i < needed - 1; i++)
   {
      if(!(highs[i] > highs[i + 1] && lows[i] > lows[i + 1]))
         bullish = false;
      if(!(highs[i] < highs[i + 1] && lows[i] < lows[i + 1]))
         bearish = false;
   }

   trend.latestHigh = highs[0];
   trend.previousHigh = highs[1];
   trend.latestLow = lows[0];
   trend.previousLow = lows[1];
   trend.latestHighShift = highShifts[0];
   trend.latestLowShift = lowShifts[0];

   if(bullish)
   {
      trend.direction = 1;
      trend.description = "Bullish - Daily higher highs and higher lows.";
   }
   else if(bearish)
   {
      trend.direction = -1;
      trend.description = "Bearish - Daily lower lows and lower highs.";
   }
   else
      trend.description = "Unclear - Daily swing sequence is mixed.";
}

// Validates H4 pullback without allowing major structure break.
void ValidateH4Pullback(string symbol, TrendInfo &trend, PullbackInfo &pullback)
{
   pullback.valid = false;
   pullback.reason = "";
   pullback.swingHigh = 0.0;
   pullback.swingLow = 0.0;
   pullback.protectedLevel = 0.0;

   double highs[];
   double lows[];
   int highShifts[];
   int lowShifts[];

   int highCount = GetRecentSwingHighs(symbol, PERIOD_H4, 3, highs, highShifts);
   int lowCount = GetRecentSwingLows(symbol, PERIOD_H4, 3, lows, lowShifts);

   if(highCount < 1 || lowCount < 1)
   {
      pullback.reason = "Not enough confirmed H4 swings.";
      return;
   }

   double closeNow = iClose(symbol, PERIOD_H4, 1);
   double lowNow = iLow(symbol, PERIOD_H4, 1);
   double highNow = iHigh(symbol, PERIOD_H4, 1);

   pullback.swingHigh = highs[0];
   pullback.swingLow = lows[0];

   if(trend.direction > 0)
   {
      double priorH4SwingLow = (lowCount >= 2) ? lows[1] : lows[0];
      pullback.protectedLevel = MathMax(trend.latestLow, priorH4SwingLow);
      bool bullishRetracedFromHigh = (closeNow < highs[0]);
      bool bullishConfirmedSwing = (!H4RequireConfirmedPullbackSwing || lowShifts[0] < highShifts[0]);
      double bullishPullbackPips = (highs[0] - lows[0]) / PipSize(symbol);
      double minPullbackPips = IsGoldSymbol(symbol) ? H4MinPullbackPipsGold : H4MinPullbackPips;
      bool bullishBrokeStructure = (lowNow <= pullback.protectedLevel || iClose(symbol, PERIOD_H4, 1) <= pullback.protectedLevel);

      if(!bullishRetracedFromHigh)
      {
         pullback.reason = "Bullish trend, but H4 has not retraced from latest swing high.";
         return;
      }
      if(!bullishConfirmedSwing)
      {
         pullback.reason = "Bullish trend, but no confirmed H4 pullback swing low after the swing high.";
         return;
      }
      if(bullishPullbackPips < minPullbackPips)
      {
         pullback.reason = "Bullish H4 pullback is too shallow: " + DoubleToString(bullishPullbackPips, 1) + " pips.";
         return;
      }
      if(bullishBrokeStructure)
      {
         pullback.reason = "Bullish setup invalidated - latest major Daily/H4 swing low broken.";
         return;
      }

      pullback.valid = true;
      pullback.reason = "Bullish H4 pullback valid. Protected low: " + DoubleToString(pullback.protectedLevel, DigitsForSymbol(symbol));
      return;
   }

   if(trend.direction < 0)
   {
      double priorH4SwingHigh = (highCount >= 2) ? highs[1] : highs[0];
      pullback.protectedLevel = MathMin(trend.latestHigh, priorH4SwingHigh);
      bool bearishRetracedFromLow = (closeNow > lows[0]);
      bool bearishConfirmedSwing = (!H4RequireConfirmedPullbackSwing || highShifts[0] < lowShifts[0]);
      double bearishPullbackPips = (highs[0] - lows[0]) / PipSize(symbol);
      double minBearishPullbackPips = IsGoldSymbol(symbol) ? H4MinPullbackPipsGold : H4MinPullbackPips;
      bool bearishBrokeStructure = (highNow >= pullback.protectedLevel || iClose(symbol, PERIOD_H4, 1) >= pullback.protectedLevel);

      if(!bearishRetracedFromLow)
      {
         pullback.reason = "Bearish trend, but H4 has not retraced from latest swing low.";
         return;
      }
      if(!bearishConfirmedSwing)
      {
         pullback.reason = "Bearish trend, but no confirmed H4 pullback swing high after the swing low.";
         return;
      }
      if(bearishPullbackPips < minBearishPullbackPips)
      {
         pullback.reason = "Bearish H4 pullback is too shallow: " + DoubleToString(bearishPullbackPips, 1) + " pips.";
         return;
      }
      if(bearishBrokeStructure)
      {
         pullback.reason = "Bearish setup invalidated - latest major Daily/H4 swing high broken.";
         return;
      }

      pullback.valid = true;
      pullback.reason = "Bearish H4 pullback valid. Protected high: " + DoubleToString(pullback.protectedLevel, DigitsForSymbol(symbol));
   }
}

// Finds entry-timeframe lower highs and a break above the most recent one.
bool DetectBullishStructureBreak(string symbol, int timeframe, double &breakLevel, string &reason)
{
   double highs[];
   int shifts[];
   int found = GetRecentSwingHighs(symbol, timeframe, 2, highs, shifts);
   if(found < 2)
   {
      reason = "Not enough entry timeframe swing highs for lower-high pullback structure.";
      return(false);
   }

   if(!(highs[0] < highs[1]))
   {
      reason = "Entry pullback has not formed lower highs.";
      return(false);
   }

   breakLevel = highs[0];
   double closeLast = iClose(symbol, timeframe, 1);
   double closePrev = iClose(symbol, timeframe, 2);

   if(closeLast > breakLevel && closePrev <= breakLevel)
   {
      reason = "Break above most recent lower high confirmed.";
      return(true);
   }

   reason = "No fresh break above most recent lower high.";
   return(false);
}

// Finds entry-timeframe higher lows and a break below the most recent one.
bool DetectBearishStructureBreak(string symbol, int timeframe, double &breakLevel, string &reason)
{
   double lows[];
   int shifts[];
   int found = GetRecentSwingLows(symbol, timeframe, 2, lows, shifts);
   if(found < 2)
   {
      reason = "Not enough entry timeframe swing lows for higher-low pullback structure.";
      return(false);
   }

   if(!(lows[0] > lows[1]))
   {
      reason = "Entry pullback has not formed higher lows.";
      return(false);
   }

   breakLevel = lows[0];
   double closeLast = iClose(symbol, timeframe, 1);
   double closePrev = iClose(symbol, timeframe, 2);

   if(closeLast < breakLevel && closePrev >= breakLevel)
   {
      reason = "Break below most recent higher low confirmed.";
      return(true);
   }

   reason = "No fresh break below most recent higher low.";
   return(false);
}

// Calculates alert-only trigger, market entry, stop loss, take profit, and reward:risk levels.
void CalculateSuggestedLevels(string symbol, int orderType, double triggerLevel, double marketPrice, double stopReference, LevelInfo &levels)
{
   int digits = DigitsForSymbol(symbol);
   double buffer = (IsGoldSymbol(symbol) ? StopBufferPipsGold : StopBufferPips) * PipSize(symbol);

   levels.valid = false;
   levels.reason = "";
   levels.triggerLevel = NormalizeDouble(triggerLevel, digits);
   levels.marketPrice = NormalizeDouble(marketPrice, digits);
   levels.entry = NormalizeDouble(marketPrice, digits);
   levels.stopLoss = 0.0;
   levels.takeProfit = 0.0;
   levels.risk = 0.0;
   levels.reward = 0.0;
   levels.rewardRisk = 0.0;

   if(stopReference <= 0.0 || triggerLevel <= 0.0 || marketPrice <= 0.0)
   {
      levels.reason = "Stop loss, trigger, or market price reference could not be calculated.";
      return;
   }

   if(orderType == OP_BUY)
   {
      levels.stopLoss = NormalizeDouble(stopReference - buffer, digits);
      levels.risk = levels.entry - levels.stopLoss;
      if(levels.risk <= 0.0)
      {
         levels.reason = "Invalid BUY risk distance.";
         return;
      }
      levels.takeProfit = NormalizeDouble(levels.entry + (levels.risk * MinRewardRisk), digits);
      levels.reward = levels.takeProfit - levels.entry;
   }
   else if(orderType == OP_SELL)
   {
      levels.stopLoss = NormalizeDouble(stopReference + buffer, digits);
      levels.risk = levels.stopLoss - levels.entry;
      if(levels.risk <= 0.0)
      {
         levels.reason = "Invalid SELL risk distance.";
         return;
      }
      levels.takeProfit = NormalizeDouble(levels.entry - (levels.risk * MinRewardRisk), digits);
      levels.reward = levels.entry - levels.takeProfit;
   }
   else
   {
      levels.reason = "Unsupported setup type.";
      return;
   }

   levels.rewardRisk = levels.reward / levels.risk;
   if(levels.rewardRisk < MinRewardRisk)
   {
      levels.reason = "Reward-to-risk below minimum.";
      return;
   }

   levels.valid = true;
   levels.reason = "Levels calculated.";
}

// Prevents repeated alerts on the same symbol, direction, and entry candle.
bool CanSendAlert(string symbol, int orderType, datetime candleTime)
{
   int index = GetSymbolIndex(symbol);
   if(index < 0)
      return(false);

   if(orderType == OP_BUY)
      return(g_lastBuyAlertTimes[index] != candleTime);
   if(orderType == OP_SELL)
      return(g_lastSellAlertTimes[index] != candleTime);

   return(false);
}

// Stores the latest alerted candle time.
void SetLastAlertTime(string symbol, int orderType, datetime candleTime)
{
   int index = GetSymbolIndex(symbol);
   if(index < 0)
      return;

   if(orderType == OP_BUY)
      g_lastBuyAlertTimes[index] = candleTime;
   else if(orderType == OP_SELL)
      g_lastSellAlertTimes[index] = candleTime;
}

// Allows scanner work and logging only once per new entry timeframe candle.
bool ShouldScanNewCandle(string symbol, datetime candleTime)
{
   int index = GetSymbolIndex(symbol);
   if(index < 0)
      return(false);

   if(g_lastScannedCandleTimes[index] == candleTime)
      return(false);

   g_lastScannedCandleTimes[index] = candleTime;
   return(true);
}

// Returns the actual alert-time market price for the direction.
double GetAlertMarketPrice(string symbol, int orderType)
{
   if(orderType == OP_BUY)
      return(MarketInfo(symbol, MODE_ASK));
   if(orderType == OP_SELL)
      return(MarketInfo(symbol, MODE_BID));
   return(0.0);
}

// Sends configured alert channels.
void SendSetupAlert(string symbol, string direction, string trendDirection, string entryTf, LevelInfo &levels)
{
   int digits = DigitsForSymbol(symbol);
   datetime sastTime = TimeCurrent() + (ServerToSASTOffsetHours * 3600);
   string message = EA_NAME + " v1.1 ALERT-ONLY\n"
      + "Symbol: " + symbol + "\n"
      + "Setup type: " + direction + "\n"
      + "Daily trend direction: " + trendDirection + "\n"
      + "H4 pullback valid: Yes\n"
      + "Entry timeframe used: " + entryTf + "\n"
      + "Break/trigger level: " + DoubleToString(levels.triggerLevel, digits) + "\n"
      + "Current market price: " + DoubleToString(levels.marketPrice, digits) + "\n"
      + "Suggested entry price: " + DoubleToString(levels.entry, digits) + "\n"
      + "Suggested stop loss: " + DoubleToString(levels.stopLoss, digits) + "\n"
      + "Suggested take profit: " + DoubleToString(levels.takeProfit, digits) + "\n"
      + "Risk-to-reward: 1:" + DoubleToString(levels.rewardRisk, 2) + "\n"
      + "Server time: " + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + "\n"
      + "SAST-adjusted time: " + TimeToString(sastTime, TIME_DATE | TIME_SECONDS);

   Print(message);

   if(EnablePopupAlert)
      Alert(message);
   if(EnablePushNotification)
      SendNotification(message);
   if(EnableEmailAlert)
      SendMail(EA_NAME + " " + symbol + " " + direction, message);
   if(EnableSoundAlert)
      PlaySound(SoundFile);
}

// Draws arrows, levels, and summary label on the attached chart.
void DrawSetupObjects(string symbol, int timeframe, string direction, datetime candleTime, LevelInfo &levels)
{
   if(symbol != Symbol())
      return;

   int digits = DigitsForSymbol(symbol);
   string prefix = "stayTRU_TCF_" + symbol + "_" + TimeframeToString(timeframe) + "_" + direction + "_" + IntegerToString((int)candleTime);
   color signalColor = direction == "BUY" ? clrLime : clrRed;
   int arrowCode = direction == "BUY" ? 233 : 234;
   DeleteObjectsByPrefix(prefix);

   string arrowName = prefix + "_Arrow";
   double arrowPrice = direction == "BUY" ? levels.entry - (10 * Point) : levels.entry + (10 * Point);
   ObjectCreate(0, arrowName, OBJ_ARROW, 0, candleTime, arrowPrice);
   ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, arrowName, OBJPROP_COLOR, signalColor);
   ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);

   DrawHorizontalLine(prefix + "_Trigger", levels.triggerLevel, clrDodgerBlue, STYLE_SOLID);
   DrawHorizontalLine(prefix + "_Entry", levels.entry, clrDeepSkyBlue, STYLE_DOT);
   DrawHorizontalLine(prefix + "_StopLoss", levels.stopLoss, clrTomato, STYLE_DASH);
   DrawHorizontalLine(prefix + "_TakeProfit", levels.takeProfit, clrLimeGreen, STYLE_DASH);

   string labelName = prefix + "_Label";
   ObjectCreate(0, labelName, OBJ_TEXT, 0, candleTime, levels.entry);
   ObjectSetText(labelName,
      direction + " | " + TimeframeToString(timeframe)
      + " | Trigger " + DoubleToString(levels.triggerLevel, digits)
      + " | Market " + DoubleToString(levels.marketPrice, digits)
      + " | SL " + DoubleToString(levels.stopLoss, digits)
      + " | TP " + DoubleToString(levels.takeProfit, digits)
      + " | RR 1:" + DoubleToString(levels.rewardRisk, 2),
      8, "Arial", signalColor);
}

// Draws a single horizontal level.
void DrawHorizontalLine(string name, double price, color lineColor, int style)
{
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetDouble(0, name, OBJPROP_PRICE1, price);
}

// Removes existing objects for the same symbol, timeframe, direction, and candle.
void DeleteObjectsByPrefix(string prefix)
{
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix, 0) == 0)
         ObjectDelete(0, name);
   }
}

// Prints structured scanner status.
void LogSetupStatus(string symbol, string stage, string status, string detail)
{
   Print(EA_NAME, " | Symbol scanned: ", symbol, " | Stage: ", stage, " | Status: ", status, " | ", detail);
}

// Returns the configured symbol index, adding chart symbol when needed.
int GetSymbolIndex(string symbol)
{
   for(int i = 0; i < ArraySize(g_symbols); i++)
   {
      if(g_symbols[i] == symbol)
         return(i);
   }

   if(ScanOnlyCurrentChartSymbol && symbol == Symbol())
      return(0);

   return(-1);
}

// Resolves configured base symbols such as EURUSD to broker symbols such as EURUSDm.
string ResolveBrokerSymbol(string requestedSymbol)
{
   string requested = TrimString(requestedSymbol);
   if(requested == "")
      return(requested);

   if(SymbolSelect(requested, true))
      return(requested);

   string requestedBase = StripSymbolSuffix(requested);
   int selectedTotal = SymbolsTotal(true);
   for(int i = 0; i < selectedTotal; i++)
   {
      string selectedSymbol = SymbolName(i, true);
      if(StripSymbolSuffix(selectedSymbol) == requestedBase)
         return(selectedSymbol);
   }

   int allTotal = SymbolsTotal(false);
   for(int j = 0; j < allTotal; j++)
   {
      string availableSymbol = SymbolName(j, false);
      if(StripSymbolSuffix(availableSymbol) == requestedBase)
      {
         SymbolSelect(availableSymbol, true);
         return(availableSymbol);
      }
   }

   return(requested);
}

// Converts broker precision into a pip size.
double PipSize(string symbol)
{
   if(IsGoldSymbol(symbol))
      return(0.1);

   int digits = DigitsForSymbol(symbol);
   double point = MarketInfo(symbol, MODE_POINT);
   if(digits == 3 || digits == 5)
      return(point * 10.0);
   return(point);
}

// Returns broker digits for a symbol.
int DigitsForSymbol(string symbol)
{
   return((int)MarketInfo(symbol, MODE_DIGITS));
}

// Detects XAUUSD even with a broker suffix.
bool IsGoldSymbol(string symbol)
{
   string upper = symbol;
   StringToUpper(upper);
   return(StringFind(upper, "XAUUSD", 0) >= 0 || StringFind(upper, "GOLD", 0) >= 0);
}

// Removes common suffixes by matching known supported base symbols.
string StripSymbolSuffix(string symbol)
{
   string upper = symbol;
   StringToUpper(upper);
   string bases[8] = {"EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "NZDUSD", "USDCAD", "XAUUSD"};

   for(int i = 0; i < 8; i++)
   {
      if(StringFind(upper, bases[i], 0) == 0)
         return(bases[i]);
   }
   return(upper);
}

// Converts MT4 timeframe constants to readable text.
string TimeframeToString(int timeframe)
{
   if(timeframe == PERIOD_M1)  return("M1");
   if(timeframe == PERIOD_M5)  return("M5");
   if(timeframe == PERIOD_M15) return("M15");
   if(timeframe == PERIOD_M30) return("M30");
   if(timeframe == PERIOD_H1)  return("H1");
   if(timeframe == PERIOD_H4)  return("H4");
   if(timeframe == PERIOD_D1)  return("D1");
   if(timeframe == PERIOD_W1)  return("W1");
   if(timeframe == PERIOD_MN1) return("MN1");
   return(IntegerToString(timeframe));
}

// Trims spaces and tabs for CSV symbol parsing.
string TrimString(string value)
{
   string result = value;
   while(StringLen(result) > 0)
   {
      string leftChar = StringSubstr(result, 0, 1);
      if(leftChar != " " && leftChar != "\t")
         break;
      result = StringSubstr(result, 1);
   }

   while(StringLen(result) > 0)
   {
      int last = StringLen(result) - 1;
      string rightChar = StringSubstr(result, last, 1);
      if(rightChar != " " && rightChar != "\t")
         break;
      result = StringSubstr(result, 0, last);
   }
   return(result);
}
