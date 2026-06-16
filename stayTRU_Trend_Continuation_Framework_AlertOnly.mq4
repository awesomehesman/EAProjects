#property strict
#property copyright "stayTRU"
#property link      ""
#property version   "1.26"
#property description "stayTRU Trend Continuation Framework - Version 1.26 Scanner and Tester Execution"

input bool   UseSessionFilter           = true;
input bool   TesterIgnoreSessionFilter  = true;
input int    StartHour                  = 9;
input int    EndHour                    = 18;
input int    ServerToSASTOffsetHours    = 0;
input int    SwingLookback              = 3;
input int    TrendSwingCount            = 3;
input bool   UseStrictDailyTrendSequence = false;
input bool   H4RequireConfirmedPullbackSwing = false;
input bool   TesterRelaxH4PullbackConfirmation = true;
input bool   H4RequireTrendRejectionCandle = true;
input bool   H4RejectionMustBreakPreviousCandle = false;
input int    H4RejectionLookbackBars   = 3;
input double H4RejectionBreakBufferPips = 1.0;
input double H4RejectionBreakBufferPipsGold = 10.0;
input double H4MinPullbackPips          = 10.0;
input double H4MinPullbackPipsGold      = 100.0;
input bool   UseH1StructureFilterForFastSymbols = false;
input int    EntryMaxBarsAfterPullbackSwing = 12;
input double EntryMinSwingImprovementPips = 3.0;
input double EntryMinSwingImprovementPipsGold = 30.0;
input double EntryBreakBufferPips       = 0.5;
input double EntryBreakBufferPipsGold   = 5.0;
input double EntryMaxCloseBeyondTriggerPips = 4.0;
input double EntryMaxCloseBeyondTriggerPipsGold = 40.0;
input bool   EntryRequireBreakCandleDirection = true;
input bool   EntryRequireRetestAfterBreak = true;
input int    EntryRetestExpiryBars      = 8;
input double EntryRetestTolerancePips   = 1.5;
input double EntryRetestTolerancePipsGold = 15.0;
input double MaxSpreadPips              = 3.0;
input double MaxSpreadPipsGold          = 50.0;
input bool   TesterUseSpreadOverride    = true;
input double TesterMaxSpreadPips        = 5.0;
input double TesterMaxSpreadPipsGold    = 80.0;
input double StopBufferPips             = 5.0;
input double StopBufferPipsGold         = 50.0;
input bool   UseH4PullbackStopReference = true;
input double MinRewardRisk              = 2.5;
input bool   UseStructuralTakeProfit    = true;
input double StructuralTargetBufferPips = 2.0;
input double StructuralTargetBufferPipsGold = 20.0;
input bool   RequireH4PremiumDiscountEntry = true;
input double BuyMaxH4RangePosition      = 0.45;
input double SellMinH4RangePosition     = 0.55;
input bool   EnableTradeExecution       = false;
input bool   TesterEnableTradeExecution = true;
input double FixedLotSize               = 0.10;
input double SlippagePips               = 2.0;
input int    MagicNumber                = 27052026;
input bool   AllowOnlyOneOpenTradePerSymbol = true;
input string TradeComment               = "stayTRU TCF";
input bool   EnablePopupAlert           = true;
input bool   EnablePushNotification     = true;
input bool   EnableEmailAlert           = false;
input bool   EnableSoundAlert           = true;
input string SoundFile                  = "alert.wav";
input bool   ScanOnlyCurrentChartSymbol = true;
input bool   TesterScanOnlyCurrentSymbol = true;
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
bool     g_pendingBuyRetest[];
bool     g_pendingSellRetest[];
double   g_pendingBuyTriggerLevels[];
double   g_pendingSellTriggerLevels[];
double   g_pendingBuyStopReferences[];
double   g_pendingSellStopReferences[];
datetime g_pendingBuyBreakTimes[];
datetime g_pendingSellBreakTimes[];

// Initializes the symbol list and alert state.
int OnInit()
{
   LoadSymbolsToScan();
   ApplyChartTheme();
   Print(EA_NAME, " v1.26 initialized. Scanner mode. Symbols loaded: ", ArraySize(g_symbols), " | Trade execution: ", ShouldExecuteTrades() ? "enabled" : "disabled");
   if(IsTesting() && UseSessionFilter && TesterIgnoreSessionFilter)
      Print(EA_NAME, " | Strategy Tester mode: session filter bypassed because TesterIgnoreSessionFilter=true.");
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
   if(ShouldUseSessionFilter() && !IsWithinTradingSession())
      return;

   if(ShouldScanOnlyCurrentSymbol())
      ScanSymbol(Symbol());
   else
   {
      for(int i = 0; i < ArraySize(g_symbols); i++)
         ScanSymbol(g_symbols[i]);
   }
}

// Keeps the live session filter intact while allowing easier Strategy Tester diagnostics.
bool ShouldUseSessionFilter()
{
   if(!UseSessionFilter)
      return(false);
   if(IsTesting() && TesterIgnoreSessionFilter)
      return(false);
   return(true);
}

// Lets Strategy Tester evaluate active pullbacks instead of requiring delayed H4 swing confirmation.
bool ShouldRequireH4ConfirmedPullbackSwing()
{
   if(IsTesting() && TesterRelaxH4PullbackConfirmation)
      return(false);
   return(H4RequireConfirmedPullbackSwing);
}

// Loads and normalizes symbols from inputs.
void LoadSymbolsToScan()
{
   if(ShouldScanOnlyCurrentSymbol())
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
   ArrayResize(g_pendingBuyRetest, ArraySize(g_symbols));
   ArrayResize(g_pendingSellRetest, ArraySize(g_symbols));
   ArrayResize(g_pendingBuyTriggerLevels, ArraySize(g_symbols));
   ArrayResize(g_pendingSellTriggerLevels, ArraySize(g_symbols));
   ArrayResize(g_pendingBuyStopReferences, ArraySize(g_symbols));
   ArrayResize(g_pendingSellStopReferences, ArraySize(g_symbols));
   ArrayResize(g_pendingBuyBreakTimes, ArraySize(g_symbols));
   ArrayResize(g_pendingSellBreakTimes, ArraySize(g_symbols));
   for(int j = 0; j < ArraySize(g_symbols); j++)
   {
      g_lastBuyAlertTimes[j] = 0;
      g_lastSellAlertTimes[j] = 0;
      g_lastScannedCandleTimes[j] = 0;
      g_pendingBuyRetest[j] = false;
      g_pendingSellRetest[j] = false;
      g_pendingBuyTriggerLevels[j] = 0.0;
      g_pendingSellTriggerLevels[j] = 0.0;
      g_pendingBuyStopReferences[j] = 0.0;
      g_pendingSellStopReferences[j] = 0.0;
      g_pendingBuyBreakTimes[j] = 0;
      g_pendingSellBreakTimes[j] = 0;
   }
}

// Main per-symbol scanner.
void ScanSymbol(string symbol)
{
   symbol = TrimString(symbol);
   if(symbol == "")
      return;

   if(!CanUseSymbol(symbol))
   {
      string resolvedSymbol = ResolveBrokerSymbol(symbol);
      if(resolvedSymbol == "" || !CanUseSymbol(resolvedSymbol))
      {
         LogSetupStatus(symbol, "INIT", "REJECTED", "Symbol could not be selected in Market Watch.");
         return;
      }
      symbol = resolvedSymbol;
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
   double allowedSpread = GetAllowedSpreadPips(symbol);
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

   if(!ValidateIntermediateStructure(symbol, trend.direction))
      return;

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
   double entryStopReference = 0.0;
   string reason = "";

   if(!DetectBullishStructureBreak(symbol, entryTf, breakLevel, entryStopReference, reason))
   {
      LogSetupStatus(symbol, "ENTRY BUY", "REJECTED", reason);
      return;
   }

   LevelInfo levels;
   double marketPrice = GetAlertMarketPrice(symbol, OP_BUY);
   if(!ValidateH4EntryLocation(symbol, OP_BUY, entryStopReference, pullback, reason))
   {
      LogSetupStatus(symbol, "LOCATION BUY", "REJECTED", reason);
      return;
   }
   LogSetupStatus(symbol, "LOCATION BUY", "VALID", reason);

   double stopReference = GetSetupStopReference(OP_BUY, entryStopReference, pullback);
   LogSetupStatus(symbol, "STOP BUY", "INFO", "Entry swing stop ref: " + DoubleToString(entryStopReference, DigitsForSymbol(symbol)) + " | Final stop ref: " + DoubleToString(stopReference, DigitsForSymbol(symbol)));

   CalculateSuggestedLevels(symbol, OP_BUY, breakLevel, marketPrice, stopReference, pullback.swingHigh, levels);
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
   ExecuteSetupTrade(symbol, OP_BUY, levels);
   SetLastAlertTime(symbol, OP_BUY, candleTime);
   LogSetupStatus(symbol, "ALERT BUY", "SENT", "Structure break above " + DoubleToString(breakLevel, DigitsForSymbol(symbol)));
}

// Processes a bearish continuation setup.
void ProcessSellSetup(string symbol, int entryTf, datetime candleTime, TrendInfo &trend, PullbackInfo &pullback)
{
   double breakLevel = 0.0;
   double entryStopReference = 0.0;
   string reason = "";

   if(!DetectBearishStructureBreak(symbol, entryTf, breakLevel, entryStopReference, reason))
   {
      LogSetupStatus(symbol, "ENTRY SELL", "REJECTED", reason);
      return;
   }

   LevelInfo levels;
   double marketPrice = GetAlertMarketPrice(symbol, OP_SELL);
   if(!ValidateH4EntryLocation(symbol, OP_SELL, entryStopReference, pullback, reason))
   {
      LogSetupStatus(symbol, "LOCATION SELL", "REJECTED", reason);
      return;
   }
   LogSetupStatus(symbol, "LOCATION SELL", "VALID", reason);

   double stopReference = GetSetupStopReference(OP_SELL, entryStopReference, pullback);
   LogSetupStatus(symbol, "STOP SELL", "INFO", "Entry swing stop ref: " + DoubleToString(entryStopReference, DigitsForSymbol(symbol)) + " | Final stop ref: " + DoubleToString(stopReference, DigitsForSymbol(symbol)));

   CalculateSuggestedLevels(symbol, OP_SELL, breakLevel, marketPrice, stopReference, pullback.swingLow, levels);
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
   ExecuteSetupTrade(symbol, OP_SELL, levels);
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

// Uses wider tester spread limits without weakening live/demo chart spread limits.
double GetAllowedSpreadPips(string symbol)
{
   if(IsTesting() && TesterUseSpreadOverride)
   {
      if(IsGoldSymbol(symbol))
         return(TesterMaxSpreadPipsGold);
      return(TesterMaxSpreadPips);
   }

   if(IsGoldSymbol(symbol))
      return(MaxSpreadPipsGold);
   return(MaxSpreadPips);
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

// Gets the highest high between two completed-bar shift indexes.
double GetHighestHighInShiftRange(string symbol, int timeframe, int startShift, int endShift)
{
   if(endShift < startShift)
      return(0.0);

   double highest = 0.0;
   for(int shift = startShift; shift <= endShift; shift++)
   {
      double value = iHigh(symbol, timeframe, shift);
      if(value <= 0.0)
         continue;
      if(highest == 0.0 || value > highest)
         highest = value;
   }
   return(highest);
}

// Gets the lowest low between two completed-bar shift indexes.
double GetLowestLowInShiftRange(string symbol, int timeframe, int startShift, int endShift)
{
   if(endShift < startShift)
      return(0.0);

   double lowest = 0.0;
   for(int shift = startShift; shift <= endShift; shift++)
   {
      double value = iLow(symbol, timeframe, shift);
      if(value <= 0.0)
         continue;
      if(lowest == 0.0 || value < lowest)
         lowest = value;
   }
   return(lowest);
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

   if(UseStrictDailyTrendSequence)
   {
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
      return;
   }

   double dailyClose = iClose(symbol, PERIOD_D1, 1);
   bool latestBullishBreak = (highs[0] > highs[1]);
   bool latestBearishBreak = (lows[0] < lows[1]);

   if(bullish || (latestBullishBreak && !latestBearishBreak && dailyClose > lows[0]))
   {
      trend.direction = 1;
      if(bullish)
         trend.description = "Bullish - Daily higher highs and higher lows.";
      else
         trend.description = "Bullish bias - latest Daily swing high broke upward; protected Daily low intact.";
      return;
   }

   if(bearish || (latestBearishBreak && !latestBullishBreak && dailyClose < highs[0]))
   {
      trend.direction = -1;
      if(bearish)
         trend.description = "Bearish - Daily lower lows and lower highs.";
      else
         trend.description = "Bearish bias - latest Daily swing low broke downward; protected Daily high intact.";
      return;
   }

   if(latestBullishBreak && latestBearishBreak)
   {
      if(highShifts[0] < lowShifts[0] && dailyClose > lows[0])
      {
         trend.direction = 1;
         trend.description = "Bullish bias - mixed Daily swings, but latest confirmed break is upward and protected low is intact.";
         return;
      }

      if(lowShifts[0] < highShifts[0] && dailyClose < highs[0])
      {
         trend.direction = -1;
         trend.description = "Bearish bias - mixed Daily swings, but latest confirmed break is downward and protected high is intact.";
         return;
      }
   }

   trend.description = "Unclear - Daily swing sequence is mixed and no dominant latest break is confirmed.";
}

// Requires H1 structure agreement for fast-symbol M15 entries.
bool ValidateIntermediateStructure(string symbol, int trendDirection)
{
   if(!UseH1StructureFilterForFastSymbols)
   {
      LogSetupStatus(symbol, "H1 FILTER", "SKIPPED", "H1 agreement filter disabled; H4 pullback and entry timeframe will confirm continuation.");
      return(true);
   }

   if(!IsFastSymbol(symbol))
      return(true);

   string reason = "";
   int h1Trend = GetStructureTrend(symbol, PERIOD_H1, 2, reason);
   if(h1Trend == trendDirection)
   {
      LogSetupStatus(symbol, "H1 FILTER", "VALID", reason);
      return(true);
   }

   LogSetupStatus(symbol, "H1 FILTER", "REJECTED", "H1 structure does not agree with Daily trend. " + reason);
   return(false);
}

// Returns basic swing-structure direction for any timeframe.
int GetStructureTrend(string symbol, int timeframe, int swingCount, string &reason)
{
   int needed = MathMax(swingCount, 2);
   double highs[];
   double lows[];
   int highShifts[];
   int lowShifts[];

   int highCount = GetRecentSwingHighs(symbol, timeframe, needed, highs, highShifts);
   int lowCount = GetRecentSwingLows(symbol, timeframe, needed, lows, lowShifts);
   if(highCount < needed || lowCount < needed)
   {
      reason = TimeframeToString(timeframe) + " has insufficient confirmed swings.";
      return(0);
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

   if(bullish)
   {
      reason = TimeframeToString(timeframe) + " higher highs and higher lows.";
      return(1);
   }
   if(bearish)
   {
      reason = TimeframeToString(timeframe) + " lower highs and lower lows.";
      return(-1);
   }

   reason = TimeframeToString(timeframe) + " structure is mixed.";
   return(0);
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
      bool bullishConfirmedSwing = (!ShouldRequireH4ConfirmedPullbackSwing() || lowShifts[0] < highShifts[0]);
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
         pullback.reason = "Bullish trend, but strict H4 confirmation requires a confirmed pullback swing low after the swing high.";
         return;
      }
      if(bullishPullbackPips < minPullbackPips)
      {
         pullback.reason = "Bullish H4 pullback is too shallow: " + DoubleToString(bullishPullbackPips, 1) + " pips.";
         return;
      }
      if(!ValidateH4TrendRejection(symbol, OP_BUY, pullback.reason))
         return;
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
      bool bearishConfirmedSwing = (!ShouldRequireH4ConfirmedPullbackSwing() || highShifts[0] < lowShifts[0]);
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
         pullback.reason = "Bearish trend, but strict H4 confirmation requires a confirmed pullback swing high after the swing low.";
         return;
      }
      if(bearishPullbackPips < minBearishPullbackPips)
      {
         pullback.reason = "Bearish H4 pullback is too shallow: " + DoubleToString(bearishPullbackPips, 1) + " pips.";
         return;
      }
      if(!ValidateH4TrendRejection(symbol, OP_SELL, pullback.reason))
         return;
      if(bearishBrokeStructure)
      {
         pullback.reason = "Bearish setup invalidated - latest major Daily/H4 swing high broken.";
         return;
      }

      pullback.valid = true;
      pullback.reason = "Bearish H4 pullback valid. Protected high: " + DoubleToString(pullback.protectedLevel, DigitsForSymbol(symbol));
   }
}

// Requires a recent closed H4 candle to reject the pullback back in trend direction.
bool ValidateH4TrendRejection(string symbol, int orderType, string &reason)
{
   if(!H4RequireTrendRejectionCandle)
      return(true);

   int lookbackBars = MathMax(H4RejectionLookbackBars, 1);
   double buffer = (IsGoldSymbol(symbol) ? H4RejectionBreakBufferPipsGold : H4RejectionBreakBufferPips) * PipSize(symbol);

   for(int shift = 1; shift <= lookbackBars; shift++)
   {
      double closeBar = iClose(symbol, PERIOD_H4, shift);
      double openBar = iOpen(symbol, PERIOD_H4, shift);
      double highBar = iHigh(symbol, PERIOD_H4, shift);
      double lowBar = iLow(symbol, PERIOD_H4, shift);
      double prevHigh = iHigh(symbol, PERIOD_H4, shift + 1);
      double prevLow = iLow(symbol, PERIOD_H4, shift + 1);
      double candleRange = highBar - lowBar;

      if(candleRange <= 0.0)
         continue;

      if(orderType == OP_BUY)
      {
         bool bullishCandle = (closeBar > openBar);
         bool bullishClosesStrong = (closeBar >= lowBar + (candleRange * 0.60));
         bool bullishBreaksPrevious = (closeBar > prevHigh + buffer);

         if(bullishCandle && (bullishClosesStrong || bullishBreaksPrevious))
         {
            if(H4RejectionMustBreakPreviousCandle && !bullishBreaksPrevious)
               continue;

            reason = "Recent H4 bullish rejection confirmed within " + IntegerToString(lookbackBars) + " closed H4 candles.";
            return(true);
         }
      }

      if(orderType == OP_SELL)
      {
         bool bearishCandle = (closeBar < openBar);
         bool bearishClosesStrong = (closeBar <= highBar - (candleRange * 0.60));
         bool bearishBreaksPrevious = (closeBar < prevLow - buffer);

         if(bearishCandle && (bearishClosesStrong || bearishBreaksPrevious))
         {
            if(H4RejectionMustBreakPreviousCandle && !bearishBreaksPrevious)
               continue;

            reason = "Recent H4 bearish rejection confirmed within " + IntegerToString(lookbackBars) + " closed H4 candles.";
            return(true);
         }
      }
   }

   if(orderType == OP_BUY)
      reason = "H4 pullback valid, but no recent bullish H4 rejection found within " + IntegerToString(lookbackBars) + " closed H4 candles.";
   else if(orderType == OP_SELL)
      reason = "H4 pullback valid, but no recent bearish H4 rejection found within " + IntegerToString(lookbackBars) + " closed H4 candles.";
   else
      reason = "Unsupported H4 rejection direction.";

   return(false);
}

// Finds an entry-timeframe higher low and a break above the post-pullback high.
bool DetectBullishStructureBreak(string symbol, int timeframe, double &breakLevel, double &stopReference, string &reason)
{
   if(CheckPendingRetestEntry(symbol, timeframe, OP_BUY, breakLevel, stopReference, reason))
      return(true);

   double lows[];
   int lowShifts[];
   int found = GetRecentSwingLows(symbol, timeframe, 2, lows, lowShifts);
   if(found < 2)
   {
      reason = "Not enough entry timeframe swing lows for higher-low pullback structure.";
      return(false);
   }

   if(!(lows[0] > lows[1]))
   {
      reason = "Entry pullback has not formed a higher low.";
      return(false);
   }

   int barsAfterHigherLow = lowShifts[0] - 1;
   if(barsAfterHigherLow > EntryMaxBarsAfterPullbackSwing)
   {
      reason = "Higher-low trigger is stale; too many bars after pullback swing.";
      return(false);
   }

   double minSwingImprovement = GetEntryMinSwingImprovementPips(symbol) * PipSize(symbol);
   if((lows[0] - lows[1]) < minSwingImprovement)
   {
      reason = "Higher low is too marginal versus previous swing low.";
      return(false);
   }

   if(lowShifts[0] <= 3)
   {
      reason = "Higher low is too recent; waiting for post-pullback break structure.";
      return(false);
   }

   breakLevel = GetHighestHighInShiftRange(symbol, timeframe, 2, lowShifts[0] - 1);
   stopReference = lows[0];
   if(breakLevel <= 0.0 || stopReference <= 0.0)
   {
      reason = "Could not calculate bullish post-pullback trigger or stop reference.";
      return(false);
   }

   double closeLast = iClose(symbol, timeframe, 1);
   double closePrev = iClose(symbol, timeframe, 2);
   double openLast = iOpen(symbol, timeframe, 1);
   double breakBuffer = GetEntryBreakBufferPips(symbol) * PipSize(symbol);
   double maxCloseBeyondTrigger = GetEntryMaxCloseBeyondTriggerPips(symbol) * PipSize(symbol);

   if(EntryRequireBreakCandleDirection && closeLast <= openLast)
   {
      reason = "Bullish break candle did not close bullish.";
      return(false);
   }

   if(closeLast > breakLevel + breakBuffer && closePrev <= breakLevel)
   {
      if((closeLast - breakLevel) > maxCloseBeyondTrigger)
      {
         reason = "Bullish break closed too far beyond trigger; entry is late.";
         return(false);
      }
      if(EntryRequireRetestAfterBreak)
      {
         StorePendingRetest(symbol, OP_BUY, breakLevel, stopReference, iTime(symbol, timeframe, 1));
         reason = "Bullish break confirmed; waiting for retest of broken trigger.";
         return(false);
      }
      reason = "Higher-low pullback confirmed; break above post-pullback high.";
      return(true);
   }

   reason = "No fresh break above post-higher-low trigger.";
   return(false);
}

// Finds an entry-timeframe lower high and a break below the post-pullback low.
bool DetectBearishStructureBreak(string symbol, int timeframe, double &breakLevel, double &stopReference, string &reason)
{
   if(CheckPendingRetestEntry(symbol, timeframe, OP_SELL, breakLevel, stopReference, reason))
      return(true);

   double highs[];
   int highShifts[];
   int found = GetRecentSwingHighs(symbol, timeframe, 2, highs, highShifts);
   if(found < 2)
   {
      reason = "Not enough entry timeframe swing highs for lower-high pullback structure.";
      return(false);
   }

   if(!(highs[0] < highs[1]))
   {
      reason = "Entry pullback has not formed a lower high.";
      return(false);
   }

   int barsAfterLowerHigh = highShifts[0] - 1;
   if(barsAfterLowerHigh > EntryMaxBarsAfterPullbackSwing)
   {
      reason = "Lower-high trigger is stale; too many bars after pullback swing.";
      return(false);
   }

   double minSwingImprovement = GetEntryMinSwingImprovementPips(symbol) * PipSize(symbol);
   if((highs[1] - highs[0]) < minSwingImprovement)
   {
      reason = "Lower high is too marginal versus previous swing high.";
      return(false);
   }

   if(highShifts[0] <= 3)
   {
      reason = "Lower high is too recent; waiting for post-pullback break structure.";
      return(false);
   }

   breakLevel = GetLowestLowInShiftRange(symbol, timeframe, 2, highShifts[0] - 1);
   stopReference = highs[0];
   if(breakLevel <= 0.0 || stopReference <= 0.0)
   {
      reason = "Could not calculate bearish post-pullback trigger or stop reference.";
      return(false);
   }

   double closeLast = iClose(symbol, timeframe, 1);
   double closePrev = iClose(symbol, timeframe, 2);
   double openLast = iOpen(symbol, timeframe, 1);
   double breakBuffer = GetEntryBreakBufferPips(symbol) * PipSize(symbol);
   double maxCloseBeyondTrigger = GetEntryMaxCloseBeyondTriggerPips(symbol) * PipSize(symbol);

   if(EntryRequireBreakCandleDirection && closeLast >= openLast)
   {
      reason = "Bearish break candle did not close bearish.";
      return(false);
   }

   if(closeLast < breakLevel - breakBuffer && closePrev >= breakLevel)
   {
      if((breakLevel - closeLast) > maxCloseBeyondTrigger)
      {
         reason = "Bearish break closed too far beyond trigger; entry is late.";
         return(false);
      }
      if(EntryRequireRetestAfterBreak)
      {
         StorePendingRetest(symbol, OP_SELL, breakLevel, stopReference, iTime(symbol, timeframe, 1));
         reason = "Bearish break confirmed; waiting for retest of broken trigger.";
         return(false);
      }
      reason = "Lower-high pullback confirmed; break below post-pullback low.";
      return(true);
   }

   reason = "No fresh break below post-lower-high trigger.";
   return(false);
}

// Returns minimum improvement required between entry timeframe swings.
double GetEntryMinSwingImprovementPips(string symbol)
{
   if(IsGoldSymbol(symbol))
      return(EntryMinSwingImprovementPipsGold);
   return(EntryMinSwingImprovementPips);
}

// Returns the close-confirmation buffer beyond the trigger.
double GetEntryBreakBufferPips(string symbol)
{
   if(IsGoldSymbol(symbol))
      return(EntryBreakBufferPipsGold);
   return(EntryBreakBufferPips);
}

// Limits late entries that close too far from the trigger level.
double GetEntryMaxCloseBeyondTriggerPips(string symbol)
{
   if(IsGoldSymbol(symbol))
      return(EntryMaxCloseBeyondTriggerPipsGold);
   return(EntryMaxCloseBeyondTriggerPips);
}

// Saves a valid structure break and waits for a retest before entry.
void StorePendingRetest(string symbol, int orderType, double triggerLevel, double stopReference, datetime breakTime)
{
   int index = GetSymbolIndex(symbol);
   if(index < 0)
      return;

   if(orderType == OP_BUY)
   {
      g_pendingBuyRetest[index] = true;
      g_pendingBuyTriggerLevels[index] = triggerLevel;
      g_pendingBuyStopReferences[index] = stopReference;
      g_pendingBuyBreakTimes[index] = breakTime;
   }
   else if(orderType == OP_SELL)
   {
      g_pendingSellRetest[index] = true;
      g_pendingSellTriggerLevels[index] = triggerLevel;
      g_pendingSellStopReferences[index] = stopReference;
      g_pendingSellBreakTimes[index] = breakTime;
   }
}

// Confirms entry only after price retests the broken trigger and rejects in trend direction.
bool CheckPendingRetestEntry(string symbol, int timeframe, int orderType, double &breakLevel, double &stopReference, string &reason)
{
   int index = GetSymbolIndex(symbol);
   if(index < 0 || !EntryRequireRetestAfterBreak)
      return(false);

   bool active = (orderType == OP_BUY) ? g_pendingBuyRetest[index] : g_pendingSellRetest[index];
   if(!active)
      return(false);

   datetime breakTime = (orderType == OP_BUY) ? g_pendingBuyBreakTimes[index] : g_pendingSellBreakTimes[index];
   int barsSinceBreak = iBarShift(symbol, timeframe, breakTime, false);
   if(barsSinceBreak < 0 || barsSinceBreak > EntryRetestExpiryBars)
   {
      ClearPendingRetest(index, orderType);
      reason = "Pending retest expired.";
      return(false);
   }

   breakLevel = (orderType == OP_BUY) ? g_pendingBuyTriggerLevels[index] : g_pendingSellTriggerLevels[index];
   stopReference = (orderType == OP_BUY) ? g_pendingBuyStopReferences[index] : g_pendingSellStopReferences[index];

   double tolerance = GetEntryRetestTolerancePips(symbol) * PipSize(symbol);
   double breakBuffer = GetEntryBreakBufferPips(symbol) * PipSize(symbol);
   double openLast = iOpen(symbol, timeframe, 1);
   double closeLast = iClose(symbol, timeframe, 1);
   double highLast = iHigh(symbol, timeframe, 1);
   double lowLast = iLow(symbol, timeframe, 1);

   if(orderType == OP_BUY)
   {
      bool retested = (lowLast <= breakLevel + tolerance);
      bool rejected = (closeLast > openLast && closeLast > breakLevel + breakBuffer);
      if(retested && rejected)
      {
         ClearPendingRetest(index, orderType);
         reason = "Bullish retest held and rejected from trigger.";
         return(true);
      }

      reason = "Waiting for bullish retest/rejection of trigger.";
      return(false);
   }

   if(orderType == OP_SELL)
   {
      bool retested = (highLast >= breakLevel - tolerance);
      bool rejected = (closeLast < openLast && closeLast < breakLevel - breakBuffer);
      if(retested && rejected)
      {
         ClearPendingRetest(index, orderType);
         reason = "Bearish retest held and rejected from trigger.";
         return(true);
      }

      reason = "Waiting for bearish retest/rejection of trigger.";
      return(false);
   }

   return(false);
}

// Clears a pending retest setup.
void ClearPendingRetest(int index, int orderType)
{
   if(index < 0)
      return;

   if(orderType == OP_BUY)
   {
      g_pendingBuyRetest[index] = false;
      g_pendingBuyTriggerLevels[index] = 0.0;
      g_pendingBuyStopReferences[index] = 0.0;
      g_pendingBuyBreakTimes[index] = 0;
   }
   else if(orderType == OP_SELL)
   {
      g_pendingSellRetest[index] = false;
      g_pendingSellTriggerLevels[index] = 0.0;
      g_pendingSellStopReferences[index] = 0.0;
      g_pendingSellBreakTimes[index] = 0;
   }
}

// Returns tolerance around a broken trigger for retest entries.
double GetEntryRetestTolerancePips(string symbol)
{
   if(IsGoldSymbol(symbol))
      return(EntryRetestTolerancePipsGold);
   return(EntryRetestTolerancePips);
}

// Requires the entry confirmation swing to form in the correct H4 value area.
bool ValidateH4EntryLocation(string symbol, int orderType, double setupSwingPrice, PullbackInfo &pullback, string &reason)
{
   if(!RequireH4PremiumDiscountEntry)
      return(true);

   double range = pullback.swingHigh - pullback.swingLow;
   if(range <= 0.0)
   {
      reason = "Invalid H4 pullback range for entry location.";
      return(false);
   }

   double position = (setupSwingPrice - pullback.swingLow) / range;

   if(orderType == OP_BUY)
   {
      if(position <= BuyMaxH4RangePosition)
      {
         reason = "BUY higher-low formed in H4 discount/value zone. Position: " + DoubleToString(position, 2);
         return(true);
      }

      reason = "BUY higher-low formed too high in the H4 range; poor continuation location. Position: " + DoubleToString(position, 2);
      return(false);
   }

   if(orderType == OP_SELL)
   {
      if(position >= SellMinH4RangePosition)
      {
         reason = "SELL lower-high formed in H4 premium/value zone. Position: " + DoubleToString(position, 2);
         return(true);
      }

      reason = "SELL lower-high formed too low in the H4 range; selling into support/exhaustion. Position: " + DoubleToString(position, 2);
      return(false);
   }

   reason = "Unsupported H4 entry location direction.";
   return(false);
}

// Uses the higher-timeframe pullback swing as the default invalidation point.
double GetSetupStopReference(int orderType, double entryStopReference, PullbackInfo &pullback)
{
   if(!UseH4PullbackStopReference)
      return(entryStopReference);

   if(orderType == OP_BUY)
   {
      if(pullback.swingLow > 0.0)
         return(MathMin(entryStopReference, pullback.swingLow));
      return(entryStopReference);
   }

   if(orderType == OP_SELL)
   {
      if(pullback.swingHigh > 0.0)
         return(MathMax(entryStopReference, pullback.swingHigh));
      return(entryStopReference);
   }

   return(entryStopReference);
}

// Keeps structural TP slightly ahead of the next swing target.
double GetStructuralTargetBufferPips(string symbol)
{
   if(IsGoldSymbol(symbol))
      return(StructuralTargetBufferPipsGold);
   return(StructuralTargetBufferPips);
}

// Calculates trigger, market entry, stop loss, take profit, and reward:risk levels.
void CalculateSuggestedLevels(string symbol, int orderType, double triggerLevel, double marketPrice, double stopReference, double targetReference, LevelInfo &levels)
{
   int digits = DigitsForSymbol(symbol);
   double buffer = (IsGoldSymbol(symbol) ? StopBufferPipsGold : StopBufferPips) * PipSize(symbol);
   double targetBuffer = GetStructuralTargetBufferPips(symbol) * PipSize(symbol);

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

      if(UseStructuralTakeProfit)
      {
         levels.takeProfit = NormalizeDouble(targetReference - targetBuffer, digits);
         if(levels.takeProfit <= levels.entry)
         {
            levels.reason = "BUY structural target is not above entry.";
            return;
         }
      }
      else
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

      if(UseStructuralTakeProfit)
      {
         levels.takeProfit = NormalizeDouble(targetReference + targetBuffer, digits);
         if(levels.takeProfit >= levels.entry)
         {
            levels.reason = "SELL structural target is not below entry.";
            return;
         }
      }
      else
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

   if(g_lastScannedCandleTimes[index] == 0)
   {
      g_lastScannedCandleTimes[index] = candleTime;
      return(true);
   }

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

// Enables real execution only when explicitly allowed, with tester execution separately controlled.
bool ShouldExecuteTrades()
{
   if(IsTesting())
      return(TesterEnableTradeExecution);
   return(EnableTradeExecution);
}

// Places a market order for Strategy Tester/demo evaluation after a valid setup.
bool ExecuteSetupTrade(string symbol, int orderType, LevelInfo &levels)
{
   if(!ShouldExecuteTrades())
   {
      LogSetupStatus(symbol, "TRADE", "SKIPPED", "Trade execution disabled.");
      return(false);
   }

   if(AllowOnlyOneOpenTradePerSymbol && HasOpenTrade(symbol))
   {
      LogSetupStatus(symbol, "TRADE", "SKIPPED", "Existing open trade found for symbol and magic number.");
      return(false);
   }

   if(!ValidateTradeStops(symbol, orderType, levels))
      return(false);

   RefreshRates();

   int digits = DigitsForSymbol(symbol);
   double lots = NormalizeTradeVolume(symbol, FixedLotSize);
   double price = 0.0;
   color arrowColor = clrNONE;

   if(orderType == OP_BUY)
   {
      price = NormalizeDouble(MarketInfo(symbol, MODE_ASK), digits);
      arrowColor = clrLime;
   }
   else if(orderType == OP_SELL)
   {
      price = NormalizeDouble(MarketInfo(symbol, MODE_BID), digits);
      arrowColor = clrRed;
   }
   else
      return(false);

   int ticket = OrderSend(symbol, orderType, lots, price, SlippagePoints(symbol), levels.stopLoss, levels.takeProfit, TradeComment, MagicNumber, 0, arrowColor);
   if(ticket < 0)
   {
      int errorCode = GetLastError();
      LogSetupStatus(symbol, "TRADE", "FAILED", "OrderSend failed. Error: " + IntegerToString(errorCode));
      ResetLastError();
      return(false);
   }

   LogSetupStatus(symbol, "TRADE", "OPENED", "Ticket " + IntegerToString(ticket) + " | Lots " + DoubleToString(lots, 2) + " | Price " + DoubleToString(price, digits));
   return(true);
}

// Keeps tester/demo orders from stacking when the user wants one position per symbol.
bool HasOpenTrade(string symbol)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == symbol && OrderMagicNumber() == MagicNumber)
         return(true);
   }
   return(false);
}

// Converts slippage pips to broker points.
int SlippagePoints(string symbol)
{
   double point = MarketInfo(symbol, MODE_POINT);
   if(point <= 0.0)
      return(0);
   return((int)MathRound((SlippagePips * PipSize(symbol)) / point));
}

// Normalizes fixed lots to broker min/max/step.
double NormalizeTradeVolume(string symbol, double requestedLots)
{
   double minLot = MarketInfo(symbol, MODE_MINLOT);
   double maxLot = MarketInfo(symbol, MODE_MAXLOT);
   double lotStep = MarketInfo(symbol, MODE_LOTSTEP);

   if(lotStep <= 0.0)
      lotStep = 0.01;

   double lots = requestedLots;
   if(lots < minLot)
      lots = minLot;
   if(lots > maxLot)
      lots = maxLot;

   lots = MathFloor(lots / lotStep) * lotStep;
   if(lots < minLot)
      lots = minLot;

   return(NormalizeDouble(lots, 2));
}

// Rejects orders when SL/TP would violate the broker's minimum stop distance.
bool ValidateTradeStops(string symbol, int orderType, LevelInfo &levels)
{
   double point = MarketInfo(symbol, MODE_POINT);
   double stopDistance = MarketInfo(symbol, MODE_STOPLEVEL) * point;
   double ask = MarketInfo(symbol, MODE_ASK);
   double bid = MarketInfo(symbol, MODE_BID);

   if(point <= 0.0)
   {
      LogSetupStatus(symbol, "TRADE", "REJECTED", "Invalid broker point size.");
      return(false);
   }

   if(orderType == OP_BUY)
   {
      if(levels.stopLoss >= bid || levels.takeProfit <= ask)
      {
         LogSetupStatus(symbol, "TRADE", "REJECTED", "BUY SL/TP are on the wrong side of market price.");
         return(false);
      }
      if(stopDistance > 0.0 && (ask - levels.stopLoss < stopDistance || levels.takeProfit - ask < stopDistance))
      {
         LogSetupStatus(symbol, "TRADE", "REJECTED", "BUY SL/TP violate broker stop level.");
         return(false);
      }
   }
   else if(orderType == OP_SELL)
   {
      if(levels.stopLoss <= ask || levels.takeProfit >= bid)
      {
         LogSetupStatus(symbol, "TRADE", "REJECTED", "SELL SL/TP are on the wrong side of market price.");
         return(false);
      }
      if(stopDistance > 0.0 && (levels.stopLoss - bid < stopDistance || bid - levels.takeProfit < stopDistance))
      {
         LogSetupStatus(symbol, "TRADE", "REJECTED", "SELL SL/TP violate broker stop level.");
         return(false);
      }
   }

   return(true);
}

// Sends configured alert channels.
void SendSetupAlert(string symbol, string direction, string trendDirection, string entryTf, LevelInfo &levels)
{
   int digits = DigitsForSymbol(symbol);
   datetime sastTime = TimeCurrent() + (ServerToSASTOffsetHours * 3600);
   string message = EA_NAME + " v1.26 SETUP\n"
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

// In Strategy Tester, MT4 normally exposes only the tested chart symbol.
bool ShouldScanOnlyCurrentSymbol()
{
   if(IsTesting() && TesterScanOnlyCurrentSymbol)
      return(true);
   return(ScanOnlyCurrentChartSymbol);
}

// Accepts the active Strategy Tester symbol even when SymbolSelect is unavailable there.
bool CanUseSymbol(string symbol)
{
   if(symbol == "")
      return(false);

   if(IsTesting() && symbol == Symbol())
      return(true);

   return(SymbolSelect(symbol, true));
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

   string requestedBase = StripSymbolSuffix(requested);
   string currentSymbol = Symbol();
   if(StripSymbolSuffix(currentSymbol) == requestedBase)
      return(currentSymbol);

   if(SymbolSelect(requested, true))
      return(requested);

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
