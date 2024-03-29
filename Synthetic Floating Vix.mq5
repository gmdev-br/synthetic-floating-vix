//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "mladen"
#property link "mladenfx@gmail.com"
#property copyright "© GM, 2020, 2021, 2022, 2023"
#property description "Synthetic Floating VIX"

#property indicator_separate_window
#property indicator_buffers 11
#property indicator_plots   9
#property indicator_label1  "Filling - VIX"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  C'45,45,45',C'45,45,45'
#property indicator_label2  "Synthetic VIX"
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  C'65,65,65',C'65,65,65',clrMagenta
#property indicator_width2  3
#property indicator_label3  "Signal - VIX"
#property indicator_type3   DRAW_COLOR_LINE
#property indicator_color3  clrNONE,clrNONE,clrNONE
#property indicator_width3  1

#property indicator_label4  "REG"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrNONE
#property indicator_width4  1

#property indicator_label5  "STDEV +1"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrNONE
#property indicator_width5  1

#property indicator_label6  "STDEV -1"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrNONE
#property indicator_width6  1

#property indicator_label7  "STDEV +2"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrNONE
#property indicator_width7  1

#property indicator_label8  "STDEV -2"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrNONE
#property indicator_width8  1

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum tipoColoracao {
   Zonas,
   Sinal
};

enum ENUM_REG_SOURCE {
   Open,           // Open
   High,           // High
   Low,             // Low
   Close,         // Close
   Typical,     // Typical
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//--- input parameters
input int                        inpVixPeriod = 20; // Synthetic VIX period
input ENUM_REG_SOURCE            inputSource = Close;
input int                        inpFlLookBack   = 48;    // Floating levels look back period
input double                     inpFlLevelUp    = 0;    // Floating levels up level %
input double                     inpFlLevelDown  = 0;    // Floating levels down level %
input int                        inpSignalPeriod = 8;
input tipoColoracao              inpTipoColoracao = Sinal;
input datetime                   DefaultInitialDate              = "2022.1.1 9:00:00";          // Data inicial padrão
input int                        WaitMilliseconds = 1500;  // Timer (milliseconds) for recalculation

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//--- buffers and global variables declarations
double val[], valc[], levup[], levdn[], signal[], signalc[];
double regChannelBuffer[];
double upChannel1[], upChannel2[];
double downChannel1[], downChannel2[];
double A, B, stdev;
datetime data_inicial;
int barFrom;
double arrayOpen[], arrayHigh[], arrayLow[], arrayClose[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
//--- indicator buffers mapping
   SetIndexBuffer(0, levup, INDICATOR_DATA);
   SetIndexBuffer(1, levdn, INDICATOR_DATA);
   SetIndexBuffer(2, val, INDICATOR_DATA);
   SetIndexBuffer(3, valc, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4, signal, INDICATOR_DATA);
   SetIndexBuffer(5, signalc, INDICATOR_COLOR_INDEX);

   ArrayInitialize(regChannelBuffer, 0);
   ArrayInitialize(upChannel1, 0);
   ArrayInitialize(downChannel1, 0);
   ArrayInitialize(upChannel2, 0);
   ArrayInitialize(downChannel2, 0);

   SetIndexBuffer(6, regChannelBuffer, INDICATOR_DATA);
   SetIndexBuffer(7, upChannel1, INDICATOR_DATA);
   SetIndexBuffer(8, downChannel1, INDICATOR_DATA);
   SetIndexBuffer(9, upChannel2, INDICATOR_DATA);
   SetIndexBuffer(10, downChannel2, INDICATOR_DATA);

   ArraySetAsSeries(regChannelBuffer, true);
   ArraySetAsSeries(upChannel1, true);
   ArraySetAsSeries(downChannel1, true);
   ArraySetAsSeries(upChannel2, true);
   ArraySetAsSeries(downChannel2, true);

   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, C'65,65,65');
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 1, C'65,65,65');

   for (int i = 0; i < 10; i++) {
      PlotIndexSetInteger(i, PLOT_SHOW_DATA, false);       //--- repeat for each plot
   }

   data_inicial = DefaultInitialDate;
   barFrom = iBarShift(NULL, PERIOD_CURRENT, data_inicial);
   _updateTimer = new MillisecondTimer(WaitMilliseconds, false);
   EventSetMillisecondTimer(WaitMilliseconds);

//--- indicator short name assignement
   IndicatorSetString(INDICATOR_SHORTNAME, "SF VIX");
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   delete(_updateTimer);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const int begin, const double &price[]) {
   return (1);
}

double workEma[][4];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double iEma(double price, double period, int r, int _bars, int instanceNo = 0) {
   if(ArrayRange(workEma, 0) != _bars) ArrayResize(workEma, _bars);

   workEma[r][instanceNo] = price;
   if(r > 0 && period > 1)
      workEma[r][instanceNo] = workEma[r - 1][instanceNo] + (2.0 / (1.0 + period)) * (price - workEma[r - 1][instanceNo]);
   return(workEma[r][instanceNo]);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool Update() {

   int totalRates = SeriesInfoInteger(NULL, PERIOD_CURRENT, SERIES_BARS_COUNT);
   int tempVar = CopyLow(NULL, PERIOD_CURRENT, 0, totalRates, arrayLow);
   tempVar = CopyClose(NULL, PERIOD_CURRENT, 0, totalRates, arrayClose);
   tempVar = CopyHigh(NULL, PERIOD_CURRENT, 0, totalRates, arrayHigh);
   tempVar = CopyOpen(NULL, PERIOD_CURRENT, 0, totalRates, arrayOpen);

   ArrayReverse(arrayLow);
   ArrayReverse(arrayClose);
   ArrayReverse(arrayHigh);
   ArrayReverse(arrayOpen);

   ArraySetAsSeries(arrayOpen, true);
   ArraySetAsSeries(arrayLow, true);
   ArraySetAsSeries(arrayClose, true);
   ArraySetAsSeries(arrayHigh, true);

   double tempVzo[];

   if(Bars(_Symbol, _Period) < totalRates)
      return false;

   double arrayAlvo[];

   if (inputSource == High)
      ArrayCopy(arrayAlvo, arrayHigh);
   else if (inputSource == Low)
      ArrayCopy(arrayAlvo, arrayLow);
   else if (inputSource == Close)
      ArrayCopy(arrayAlvo, arrayClose);
   else if (inputSource == Open)
      ArrayCopy(arrayAlvo, arrayOpen);

   ArraySetAsSeries(arrayAlvo, true);

   for(int i = 0; i < totalRates; i++) {
      int    _start   = MathMax(i - inpVixPeriod + 1, 0);
      double _highest = arrayAlvo[ArrayMaximum(arrayAlvo, _start, inpVixPeriod)];
      val[i]  = 100.0 * (_highest - arrayAlvo[i]) / _highest;

      //double _lowest = low[ArrayMinimum(low, _start, inpVixPeriod)];
      //val[i]  = 100.0 * (high[i] - _lowest) / _lowest;
      signal[i]  = iEma(val[i], inpSignalPeriod, i, totalRates, 3);

      _start = MathMax(i - inpFlLookBack, 0);
      double min = val[ArrayMinimum(val, _start, inpFlLookBack)];
      double max = val[ArrayMaximum(val, _start, inpFlLookBack)];
      double range = max - min;
      levup[i] = min + inpFlLevelUp * range / 100.0;
      //mid[i] = min + 50 * range / 100.0;
      levdn[i] = min + inpFlLevelDown * range / 100.0;

      if (inpTipoColoracao == Zonas)
         valc[i]  = (val[i] > levup[i]) ? 2 : (val[i] < levdn[i]) ? 1 : 0;
      if (inpTipoColoracao == Sinal)
         valc[i]  = (val[i] > signal[i]) ? 2 : (val[i] < signal[i]) ? 1 : 0;

      //signalc[i] = valc[i];
   }

   double dataArray[];
   ArrayCopy(dataArray, val);
   ArrayReverse(dataArray);
   barFrom = iBarShift(NULL, PERIOD_CURRENT, data_inicial);

   CalcAB(dataArray, 0, barFrom, A, B);
   stdev = GetStdDev(dataArray, 0, barFrom); //calculate standand deviation


   for(int n = 0; n < ArraySize(regChannelBuffer) - 1; n++) {
      regChannelBuffer[n] = 0.0;
      upChannel2[n] = 0.0;
      upChannel1[n] = 0.0;
      downChannel1[n] = 0.0;
      downChannel2[n] = 0.0;
   }

   for (int i = 0; i < barFrom  && !_StopFlag; i++) {
      upChannel2[i] = (A * (i) + B) + 3 * stdev;
      upChannel1[i] = (A * (i) + B) + 2 * stdev;
      regChannelBuffer[i] = (A * (i) + B);
      downChannel1[i] = (A * (i) + B) - 1 * stdev;
      downChannel2[i] = (A * (i) + B) + 3 * stdev;
   }

   return true;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//Linear Regression Calculation for sample data: arr[]
//line equation  y = f(x)  = ax + b
void CalcAB(const double &arr[], int start, int end, double & a, double & b) {

   a = 0.0;
   b = 0.0;
   int size = MathAbs(start - end) + 1;
   if(size < 2)
      return;

   double sumxy = 0.0, sumx = 0.0, sumy = 0.0, sumx2 = 0.0;
   for(int i = start; i < end; i++) {
      sumxy += i * arr[i];
      sumy += arr[i];
      sumx += i;
      sumx2 += i * i;
   }

   double M = size * sumx2 - sumx * sumx;
   if(M == 0.0)
      return;

   a = (size * sumxy - sumx * sumy) / M;
   b = (sumy - a * sumx) / size;

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetStdDev(const double & arr[], int start, int end) {
   int size = MathAbs(start - end) + 1;
   if(size < 2)
      return(0.0);

   double sum = 0.0;
   for(int i = start; i < end; i++) {
      sum = sum + arr[i];
   }

   sum = sum / size;

   double sum2 = 0.0;
   for(int i = start; i < end; i++) {
      sum2 = sum2 + (arr[i] - sum) * (arr[i] - sum);
   }

   sum2 = sum2 / (size - 1);
   sum2 = MathSqrt(sum2);

   return(sum2);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class MillisecondTimer {

 private:
   int               _milliseconds;
 private:
   uint              _lastTick;

 public:
   void              MillisecondTimer(const int milliseconds, const bool reset = true) {
      _milliseconds = milliseconds;

      if(reset)
         Reset();
      else
         _lastTick = 0;
   }

 public:
   bool              Check() {
      uint now = getCurrentTick();
      bool stop = now >= _lastTick + _milliseconds;

      if(stop)
         _lastTick = now;

      return(stop);
   }

 public:
   void              Reset() {
      _lastTick = getCurrentTick();
   }

 private:
   uint              getCurrentTick() const {
      return(GetTickCount());
   }

};

bool _lastOK = false;
MillisecondTimer *_updateTimer;

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer() {
   CheckTimer();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckTimer() {
   EventKillTimer();

   if(_updateTimer.Check() || !_lastOK) {
      _lastOK = Update();
      //Print("aaaaa");

      EventSetMillisecondTimer(WaitMilliseconds);

      _updateTimer.Reset();
   } else {
      EventSetTimer(1);
   }
}

//+---------------------------------------------------------------------+
//| GetTimeFrame function - returns the textual timeframe               |
//+---------------------------------------------------------------------+
string GetTimeFrame(int lPeriod) {
   switch(lPeriod) {
   case PERIOD_M1:
      return("M1");
   case PERIOD_M2:
      return("M2");
   case PERIOD_M3:
      return("M3");
   case PERIOD_M4:
      return("M4");
   case PERIOD_M5:
      return("M5");
   case PERIOD_M6:
      return("M6");
   case PERIOD_M10:
      return("M10");
   case PERIOD_M12:
      return("M12");
   case PERIOD_M15:
      return("M15");
   case PERIOD_M20:
      return("M20");
   case PERIOD_M30:
      return("M30");
   case PERIOD_H1:
      return("H1");
   case PERIOD_H2:
      return("H2");
   case PERIOD_H3:
      return("H3");
   case PERIOD_H4:
      return("H4");
   case PERIOD_H6:
      return("H6");
   case PERIOD_H8:
      return("H8");
   case PERIOD_H12:
      return("H12");
   case PERIOD_D1:
      return("D1");
   case PERIOD_W1:
      return("W1");
   case PERIOD_MN1:
      return("MN1");
   }
   return IntegerToString(lPeriod);
}
//+------------------------------------------------------------------+
