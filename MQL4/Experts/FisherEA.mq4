//+------------------------------------------------------------------+
//|                                                     FisherEA.mq4 |
//|                                                         Luke Yan |
//|                                               https://jyyan.info |
//|                  Credit: Yumerain (EA Sample & Indicators Style) |
//+------------------------------------------------------------------+
//--- indicator settings
#property indicator_color1  DodgerBlue
#property indicator_chart_window
#property strict
#property indicator_buffers 4
#property indicator_color1 LightSeaGreen
#property indicator_color2 LightSeaGreen
#property indicator_color3 LightSeaGreen

#define X_OFFSET 300
#define Y_START 40
#define Y_GAP 20

//定義本EA操作的訂單的唯一標識號碼，由此可以實現在同一帳戶上多系統操作，各操作EA的訂單標識碼不同，就不會互相誤操作。凡是EA皆不可缺少，非常非常重要！
#define MAGICMA  20230111

input double   MaxLots              = 0.14;// 每手倉位上限
input double   TxBudget             = 0.1; // 每手風險百分比 3% ~ 7%
input double   SL                   = 42;  // 停損基準(紅球) 36 ~ 57
input double   RR                   = 2.5; // 風報比(綠球)
input double   MaxSLMultiple        = -3;  // 停損比(黑球)
input double   MaxTPMultiple        = 11;  // 停利比(金球)
input int      FindEntryPeriod = 10;       // 搜尋進場點位範圍
input int      TrendPeriod   = 50;         // 指數統計週期
input double   AtrSlwM      = 2.8;         // 慢線 ATR 比
input double   AtrFstM      = 2.35;        // 快線 ATR 比
input int      MaxTotalTicket = 20;        // 最大在場持倉數
input int      ATRTimeframe = PERIOD_M15;  // ATR 計算區間 (1,5,15,30,60,240)

input int TriggerBP = 1;     // 買點參數 > 0
input int TriggerSP = -1;    // 賣點參數 < 0
input double TriggerATR = 8; // ATR 觸發交易基準
input int vSlippage = 5;     // 允許滑點 (2-100)

// INFO
double vPoint;
int   LotsSize             = 250;   // 每手合約數
double   LotsStep          = 0.01;  // 每手最小值
double MinStopLevel;
//--- buffers
double ExtATRBuffer[];
double ExtTRBuffer[];
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

MqlRates dayRates[2];
int timeOfferset = 0;
int findEntryCnt = 0;
int shortEntryCnt = 0;
int magicNo; // 控制每 1 單位 K 線只下一張單
int magicTick = 0;
int triggetTick;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
//--- create timer
  EventSetTimer(1);
//---
  Print("Fisher's Creed:");
  Print("像釣魚一樣有耐心，同時像赤子般對「市場」保持敬畏之心。");
  
  Print("我會為自己的投資結果負起完全的責任，並且管好自己的心態。");
  Print("獲利的部位我會耐心抱得越久越好；虧損的部位我會按規則當機立斷處理它。");
  Print("我會有耐心，並懂得運用復利的威力！");
  Print("我善於接受，並樂於奉獻我所擁有的一切！");
  Print("就算恐懼我依然會採取行動！");
  Print("我有個財務自由的腦袋！！");

  Print("=====系統參數=====");

  LotsSize = MarketInfo(Symbol(), MODE_LOTSIZE);
  LotsStep = MarketInfo(Symbol(), MODE_LOTSTEP);
  MinStopLevel = MarketInfo(Symbol(),MODE_STOPLEVEL);

  Print("MinStopLevel = ", MinStopLevel);
  Print("Point = ", Point);
  Print("MODE_LOTSIZE = ", MarketInfo(Symbol(), MODE_LOTSIZE));
  Print("MODE_LOTSTEP = ", MarketInfo(Symbol(), MODE_LOTSTEP));
  Print("MODE_MINLOT = ", MarketInfo(Symbol(), MODE_MINLOT));
  Print("MODE_MAXLOT = ", MarketInfo(Symbol(), MODE_MAXLOT));

//建立對象
  ObjectCreate(0,"lblTimer",OBJ_LABEL,0,NULL,NULL);
  ObjectCreate(0,"lblTrend",OBJ_LABEL,0,NULL,NULL);
  ObjectCreate(0,"lblTrendInfo",OBJ_LABEL,0,NULL,NULL);
  ObjectCreate(0,"lblTrendInfo2",OBJ_LABEL,0,NULL,NULL);
  ObjectCreate(0,"lblTrendInfo3",OBJ_LABEL,0,NULL,NULL);
  ObjectCreate(0,"lblTradeSignal",OBJ_LABEL,0,NULL,NULL);
  ObjectCreate(0,"lblAvailable",OBJ_LABEL,0,NULL,NULL);
  ObjectCreate(0,"lblAuthor",OBJ_LABEL,0,NULL,NULL);
//設定內容
  ObjectSetString(0,"lblTimer",OBJPROP_TEXT,_Symbol + "：H1蠟燭剩餘");
  ObjectSetString(0,"lblTrend",OBJPROP_TEXT,"指標判斷");
  ObjectSetString(0,"lblTrendInfo",OBJPROP_TEXT,"指標");
  ObjectSetString(0,"lblTrendInfo2",OBJPROP_TEXT,"指標");
  ObjectSetString(0,"lblTrendInfo3",OBJPROP_TEXT,"指標");
  ObjectSetString(0,"lblTradeSignal",OBJPROP_TEXT,"交易訊號");
  ObjectSetString(0,"lblAvailable",OBJPROP_TEXT,"Pf / RR");
  ObjectSetString(0,"lblAuthor",OBJPROP_TEXT,"作者：LukeYan");
//設定顏色
  ObjectSetInteger(0,"lblTimer",OBJPROP_COLOR,clrLimeGreen);
  ObjectSetInteger(0,"lblTrend",OBJPROP_COLOR,clrRed);
  ObjectSetInteger(0,"lblTrendInfo",OBJPROP_COLOR,clrRed);
  ObjectSetInteger(0,"lblTrendInfo2",OBJPROP_COLOR,clrRed);
  ObjectSetInteger(0,"lblTrendInfo3",OBJPROP_COLOR,clrRed);
  ObjectSetInteger(0,"lblTradeSignal",OBJPROP_COLOR,clrGold);
  ObjectSetInteger(0,"lblAvailable",OBJPROP_COLOR,clrDeepSkyBlue);
  ObjectSetInteger(0,"lblAuthor",OBJPROP_COLOR,clrGray);
//--- 定位右上角
  ObjectSetInteger(0,"lblTimer",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
  ObjectSetInteger(0,"lblTrend",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
  ObjectSetInteger(0,"lblTrendInfo",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
  ObjectSetInteger(0,"lblTrendInfo2",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
  ObjectSetInteger(0,"lblTrendInfo3",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
  ObjectSetInteger(0,"lblTradeSignal",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
  ObjectSetInteger(0,"lblAvailable",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
  ObjectSetInteger(0,"lblAuthor",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
//--- 定位右下角
//ObjectSetInteger(0,"lblAdvice",OBJPROP_CORNER,CORNER_RIGHT_LOWER);
//設定XY坐標
  ObjectSetInteger(0,"lblTimer",OBJPROP_XDISTANCE,X_OFFSET);
  ObjectSetInteger(0,"lblTimer",OBJPROP_YDISTANCE,Y_START);
  ObjectSetInteger(0,"lblTrend",OBJPROP_XDISTANCE,X_OFFSET);
  ObjectSetInteger(0,"lblTrend",OBJPROP_YDISTANCE,Y_START + Y_GAP);
  ObjectSetInteger(0,"lblTrendInfo",OBJPROP_XDISTANCE,X_OFFSET * 5);
  ObjectSetInteger(0,"lblTrendInfo",OBJPROP_YDISTANCE,Y_START + Y_GAP);
  ObjectSetInteger(0,"lblTrendInfo2",OBJPROP_XDISTANCE,X_OFFSET * 5);
  ObjectSetInteger(0,"lblTrendInfo2",OBJPROP_YDISTANCE,Y_START + Y_GAP * 2);
  ObjectSetInteger(0,"lblTrendInfo3",OBJPROP_XDISTANCE,X_OFFSET * 5);
  ObjectSetInteger(0,"lblTrendInfo3",OBJPROP_YDISTANCE,Y_START + Y_GAP * 3);
  ObjectSetInteger(0,"lblTradeSignal",OBJPROP_XDISTANCE,X_OFFSET);
  ObjectSetInteger(0,"lblTradeSignal",OBJPROP_YDISTANCE,Y_START + Y_GAP * 2);
  ObjectSetInteger(0,"lblAvailable",OBJPROP_XDISTANCE,X_OFFSET);
  ObjectSetInteger(0,"lblAvailable",OBJPROP_YDISTANCE,Y_START + Y_GAP * 3);
  ObjectSetInteger(0,"lblAuthor",OBJPROP_XDISTANCE,X_OFFSET);
  ObjectSetInteger(0,"lblAuthor",OBJPROP_YDISTANCE,Y_START + Y_GAP * 4);

// 據觀察，黃金，原油等圖示畫出來的線像右邊偏移了一個小時
  if(_Symbol == "XAUUSD" || _Symbol == "XTIUSD")timeOfferset = 60 * 60;
// 日線軸心//畫線時，時間往前移1小時(60秒*60分)
  CopyRates(_Symbol,PERIOD_D1,0,2,dayRates);

//日線PP
  ObjectCreate(0,"lnDayPP",OBJ_TREND,0,dayRates[1].time + timeOfferset,dayRates[0].close,Time[0],dayRates[0].close);
  ObjectSetInteger(0,"lnDayPP",OBJPROP_COLOR,clrRed);
  ObjectSetInteger(0,"lnDayPP",OBJPROP_STYLE,STYLE_SOLID);
  ObjectSetInteger(0,"lnDayPP",OBJPROP_WIDTH,1);
//日線S1
  ObjectCreate(0,"lnDayS1",OBJ_TREND,0,dayRates[1].time + timeOfferset,dayRates[0].close,Time[0],dayRates[0].close);
  ObjectSetInteger(0,"lnDayS1",OBJPROP_COLOR,clrRed);
  ObjectSetInteger(0,"lnDayS1",OBJPROP_STYLE,STYLE_DOT);
  ObjectSetInteger(0,"lnDayS1",OBJPROP_WIDTH,1);
//日線R1
  ObjectCreate(0,"lnDayR1",OBJ_TREND,0,dayRates[1].time + timeOfferset,dayRates[0].close,Time[0],dayRates[0].close);
  ObjectSetInteger(0,"lnDayR1",OBJPROP_COLOR,clrRed);
  ObjectSetInteger(0,"lnDayR1",OBJPROP_STYLE,STYLE_DOT);
  ObjectSetInteger(0,"lnDayR1",OBJPROP_WIDTH,1);

  /* 重新計算進場點位，從 N 到 N - 1 根 */
  findEntryCnt = 0;
  for(int x = 1; x <= FindEntryPeriod; x++) {
    double findCP = iClose(_Symbol, _Period, x);
    double findOP = iOpen(_Symbol, _Period, x);
    double findATR = iATR(_Symbol,_Period,TrendPeriod, x);
    double findMA = iMA(_Symbol,_Period,TrendPeriod, x, MODE_SMA,PRICE_CLOSE, 0);
    double findTopAtrFst = (findMA + findATR * AtrFstM);
    double findBotAtrFst = (findMA - findATR * AtrFstM);
    double findTopAtrSlw = (findMA + findATR * AtrSlwM);
    double findBotAtrSlw = (findMA - findATR * AtrSlwM);
    if (findCP < findBotAtrSlw) {
      findEntryCnt += 1;
    } else if (findCP > findTopAtrSlw) {
      findEntryCnt -= 1;
    } else if (findCP < findBotAtrFst && findCP > findBotAtrFst && findATR >= TriggerATR) {
      break;
    }
  }
  if (Point == 0.00001) {
    vPoint = 0.0001;
  } else if (Point == 0.001) {
    vPoint = 0.01;
  } else {
    vPoint = Point;
  }

  return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//--- destroy timer
  EventKillTimer();

}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
// 檢測蠟燭圖是否足夠數量，數量少了不足以形成可靠的週期線
  if(Bars(_Symbol,_Period) < 60) { // 如果總柱數少於60
    Print("我們只有不到60個報價柱，無法用於計算可靠的指標, EA 將要退出!!");
    return;
  }

  magicNo = TimeHour(TimeCurrent()); // 控制每 1 單位 K 線只下一張單
  magicTick = TimeMinute(TimeCurrent()); // 每分鐘觸發一次計算
//---
// 【多空反轉訊號】
// 多：K柱第一次收價在[方向]均線上方(最低價大於均線值)，並且均線向上，標記【做多】
// 空：K柱第一次收價在[方向]均線下方(最高價小於均線值)，並且均線向下，標記【做空】
// 當形成新的K線柱時前一根k柱剛剛收盤，判斷方法：當前K線的成交價次數>1時

  CalcKeltner();
}
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer() {
//---
// 定時刷新計算當前蠟燭剩餘時間
  long hour = Time[0] + 60 * Period() - TimeCurrent();
  long minute = (hour - hour % 60) / 60;
  long second = hour % 60;
  ObjectSetString(0,"lblTimer",OBJPROP_TEXT,StringFormat("%s：H1蠟燭剩餘：%d分%d秒",_Symbol,minute,second));

  PP();
}
//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester() {
//---
  double ret = 0.0;
//---

//---
  return(ret);
}
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam) {
//---

}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| 指標計算                                                         |
//+------------------------------------------------------------------+
void CalcKeltner() {
  if (triggetTick == magicNo && (magicTick + 1) % 15 != 0) {
    return;
  }
  triggetTick = magicNo;

  // 倉位計算
  double balance = AccountBalance();
  double totalLots = balance / LotsSize; // 可用倉位
  // 已持倉
  double hasLots = 0;
  for(int i = 0; i < OrdersTotal(); i++) {
    if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) {
      Print("注意！選中倉單失敗！序號=[",i,"]");
      continue;
    }
    if(OrderType() == OP_BUY || OrderType() == OP_SELL) {
      if(OrderSymbol() == "XTIUSD") {
        hasLots += (OrderLots() / 5.0);
      } else {
        hasLots += OrderLots();
      }
    }
  }

  double availableLots = totalLots - hasLots;
  // 高風險品種倉位減半
  if(_Symbol == "XAUUSD") {
    availableLots /= 2;
  }
  //
  // 計算下次下單倉位(數量)
  // 依 1. 每筆風險百分比 2. 初手倉位
  //
  double _SL = SL;
  double _Lots = MathCeil(balance * TxBudget / _SL / LotsSize / LotsStep) * LotsStep;
  /*
  Print("CheckPoint, balance=", DoubleToString(balance));
  Print("CheckPoint, TxBudget=", DoubleToString(TxBudget));
  Print("CheckPoint, balance * TxBudget=", DoubleToString(balance * TxBudget));
  Print("CheckPoint, _SL=", DoubleToString(_SL));
  Print("CheckPoint, balance * TxBudget / _SL=", DoubleToString(balance * TxBudget / _SL));
  Print("CheckPoint, LotsSize=", IntegerToString(LotsSize));
  Print("CheckPoint, _Lots=((balance * TxBudget) / _SL) / LotsSize=", DoubleToString(_Lots));
  */
  if (_Lots < LotsStep) _Lots = LotsStep;
  if (_Lots > MaxLots) _Lots = MaxLots;

  double MacdCurrent,MacdPrevious;
  double SignalCurrent,SignalPrevious;
  double MaCurrent,MaPrevious;
// 趨勢週期的收盤快慢均線
  double maFst = iMA(_Symbol,_Period,TrendPeriod,0,MODE_SMA,PRICE_CLOSE,0);
  double maSlw = iMA(_Symbol,_Period,TrendPeriod,0,MODE_SMA,PRICE_CLOSE,0);
// 趨勢週期的收盤快慢均線
  double maFstPre = iMA(_Symbol,_Period,TrendPeriod,0,MODE_SMA,PRICE_CLOSE,0);
  double maSlwPre = iMA(_Symbol,_Period,TrendPeriod,0,MODE_SMA,PRICE_CLOSE,0);

  double atrFst = iATR(_Symbol,_Period,TrendPeriod,1);
  double atrSlw = iATR(_Symbol,_Period,TrendPeriod,1);


  double priceBid = MarketInfo(_Symbol, MODE_BID); // 賣價
  double priceAsk = MarketInfo(_Symbol, MODE_ASK); // 買價

  double closePrice = iClose(_Symbol, _Period,1);
  double openPrice = iOpen(_Symbol, _Period,1);

  double closePricePre = iClose(_Symbol, _Period,2);
  double openPricePre = iOpen(_Symbol, _Period,2);

  bool isIncrease = closePrice > openPrice;
  bool isIncreasePre = closePricePre > openPricePre;

  double topAtrFst = (maFst + atrFst * AtrFstM);
  double botAtrFst = (maFst - atrFst * AtrFstM);
  double topAtrSlw = (maSlw + atrSlw * AtrSlwM);
  double botAtrSlw = (maSlw - atrSlw * AtrSlwM);
  MacdCurrent = iMACD(_Symbol,0,12,26,9,PRICE_CLOSE,MODE_MAIN,0);
  MacdPrevious = iMACD(_Symbol,0,12,26,9,PRICE_CLOSE,MODE_MAIN,1);
  SignalCurrent = iMACD(_Symbol,0,12,26,9,PRICE_CLOSE,MODE_SIGNAL,0);
  SignalPrevious = iMACD(_Symbol,0,12,26,9,PRICE_CLOSE,MODE_SIGNAL,1);
  MaCurrent = iMA(_Symbol,_Period,TrendPeriod,0,MODE_EMA,PRICE_CLOSE,0);
  MaPrevious = iMA(_Symbol,_Period,TrendPeriod,0,MODE_EMA,PRICE_CLOSE,1);

  // 遍歷訂單，統計盈利
  double totalProfit = SumProfit();

  bool vS = closePrice < topAtrFst && atrFst >= TriggerATR;
  bool sS = closePrice < maFst && closePrice > botAtrSlw && atrFst >= TriggerATR / 2 && availableLots >= 20 && totalProfit > 50;
  bool vB = closePrice > botAtrFst && atrFst >= TriggerATR;
  bool sB = closePrice > maFst && closePrice < topAtrSlw && atrFst >= TriggerATR / 2 && availableLots >= 20 && totalProfit > 50;


  // 每 M15 進行下單檢查
  if (magicTick == 0) {
    // Print("CheckPoint, balance=", DoubleToString(balance));
    // Print("CheckPoint, AFTER _Lots=", DoubleToString(_Lots));
    /* 使用逆勢交易*/

    /* 動態檢查停損停利點 */
    /* 當:漲勢時，檢查「空單」停利點 */
    /* 當:跌勢時，檢查「多單」停利點 */
    if (closePrice < botAtrSlw) {
      findEntryCnt += 1;

      // 收盤價低於慢線，立即出清持倉
      if (totalProfit > SL * RR * MaxTPMultiple || totalProfit < SL * MaxSLMultiple) {
        CloseAllOrder(OP_SELL);
      }
    }
    if (closePrice > topAtrSlw) {
      findEntryCnt -= 1;

      // 收盤價高於慢線，立即出清持倉
      if (totalProfit > SL * RR * MaxTPMultiple || totalProfit < SL * MaxSLMultiple) {
        CloseAllOrder(OP_BUY);
      }
    }
    ObjectSetString(0,"lblTradeSignal",OBJPROP_TEXT,"交易訊號：無");
    if (findEntryCnt < TriggerSP && vS) {
      // 資金管理：計算開倉量
      // 開倉計算
      CalcForOpen(OP_SELL, _Lots, _SL, RR * MaxTPMultiple, StringFormat("cp:%f, EntryPoint:%d, tSP:%d, MA:%f, ATR:%f, tSK:%f, tFK:%f",closePrice, findEntryCnt, TriggerSP, maFst, atrSlw, topAtrSlw, topAtrFst));
      ObjectSetString(0,"lblTradeSignal",OBJPROP_TEXT,"交易訊號：買多");
      // 抵達開倉條件時，即出清當前「多單」持倉
      CloseAllOrder(OP_BUY);
      findEntryCnt = 0; // clear counter
    }
    if (findEntryCnt > TriggerBP && vB) {
      // 資金管理：計算開倉量
      // 開倉計算
      CalcForOpen(OP_BUY, _Lots, _SL, RR * MaxTPMultiple, StringFormat("cp:%f, EntryPoint:%d, tSP:%d, MA:%f, ATR:%f, bSK:%f, bFK:%f",closePrice, findEntryCnt, TriggerBP, maFst, atrSlw, botAtrSlw, botAtrFst));
      ObjectSetString(0,"lblTradeSignal",OBJPROP_TEXT,"交易訊號：賣空");
      // 抵達開倉條件時，即出清當前「空單」持倉
      CloseAllOrder(OP_SELL);
      findEntryCnt = 0; // clear counter
    }
  } else {
    /* 使用順勢交易 */
  }


  ObjectSetString(0, "lblAvailable", OBJPROP_TEXT, "Pf. / Ava.：USD " + DoubleToStr(totalProfit,2) + " / " + DoubleToStr(availableLots,2) + " Lots");


  ObjectSetString(0,"lblTrendInfo",OBJPROP_TEXT,  StringFormat("K1:%f, %f (%f) M:%f", botAtrFst, topAtrFst,AtrFstM, maFst));
  ObjectSetString(0,"lblTrendInfo2",OBJPROP_TEXT, StringFormat("K2:%f, %f (%f) A:%f", botAtrSlw, topAtrSlw,AtrSlwM, atrSlw));
  ObjectSetString(0,"lblTrendInfo3",OBJPROP_TEXT, StringFormat("op:%f, cp:%f, i:%d, V:%d, vB:%d, vS:%d", openPrice, closePrice, isIncrease,findEntryCnt, vB, vS));

  /*
  Print(StringFormat("openPrice %f closePrice %f, isIncrease = %d, botAtrSlw %f topAtrSlw %f, botAtrFst %f topAtrFst %f, findEntryCnt %d",openPrice, closePrice, isIncrease,
  botAtrSlw,topAtrSlw,
  botAtrFst, topAtrFst, findEntryCnt));
  Print(StringFormat("isBuySignal %d isSellSignal %d",isBuySignal, isSellSignal));
  */

  return;
}

//+------------------------------------------------------------------+
//| 樞紐軸心PP                                                       |
//+------------------------------------------------------------------+
void PP() {
//典型： (yesterday_high + yesterday_low + yesterday_close)/3
//給予收盤價更高權重： (yesterday_high + yesterday_low +2* yesterday_close)/4
  CopyRates(_Symbol,PERIOD_D1,0,2,dayRates);
  double dayHigh =  dayRates[0].high;
  double dayLow =  dayRates[0].low;
  double dayClose = dayRates[0].close;
// 軸心
  double dayPP = (dayHigh + dayLow + dayClose) / 3;
// 支撐1：(2 * P) - H
// 阻力1： (2 * P) - L
  double dayS1 = 2 * dayPP - dayHigh;
  double dayR1 = 2 * dayPP - dayLow;

  ObjectMove(0,"lnDayPP",0,dayRates[1].time + timeOfferset,dayPP);
  ObjectMove(0,"lnDayPP",1,Time[0],dayPP);
  ObjectMove(0,"lnDayS1",0,dayRates[1].time + timeOfferset,dayS1);
  ObjectMove(0,"lnDayS1",1,Time[0],dayS1);
  ObjectMove(0,"lnDayR1",0,dayRates[1].time + timeOfferset,dayR1);
  ObjectMove(0,"lnDayR1",1,Time[0],dayR1);
}


//+------------------------------------------------------------------+
/* 統計當前圖表貨幣的持倉訂單數 */
//+------------------------------------------------------------------+
int OrdersCount() {
  int count = 0;
// 遍歷訂單處理
  for(int i = 0; i < OrdersTotal(); i++) {
    // 選中倉單，選擇不成功時，跳過本次循環
    if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == false) {
      Print("注意！選中倉單失敗！序號=[",i,"]");
      continue;
    }
    /*//如果 倉單編號不是本系統編號，或者 倉單貨幣對不是當前貨幣對時，跳過本次循環
    if(OrderMagicNumber() != MAGICMA || OrderSymbol()!= _Symbol)
    {
       Print("注意！訂單魔術標記不符！倉單魔術編號=[",OrderMagicNumber(),"]","本EA魔術編號=[",MAGICMA,"]");
       continue;
    }*/
    if(OrderSymbol() == _Symbol) {
      count++;
    }
  }
  return count;
}

//+------------------------------------------------------------------+
/* 計算開倉:依風報比 RR 值開倉 */
//+------------------------------------------------------------------+
int lastOpenMagicNo[10];
void CalcForOpen(int cmd, double _Lots, double _SL, double _RR, string comment = "", int magicSlot = 0, int _magicNo = 0) {
  // 當前貨幣持倉情況下不開新倉
  int openCount = OrdersCount();

  int openMagicNo = _magicNo > 0 ? _magicNo : magicNo;
  if(openCount > MaxTotalTicket || lastOpenMagicNo[magicSlot] == openMagicNo) {
    Print("當前貨幣[",_Symbol,"]開倉數量=[",openCount,"]");
    Print("GetLastError=", GetLastError());
    return;
  }
  lastOpenMagicNo[magicSlot] = openMagicNo;

  // Get current market prices.
  RefreshRates();
  /*
  買賣報價是站在「金融機構」的立場，以銀行匯兌外幣為例，
  買進價或委買價（Bid）是銀行向投資人"買進"的價格（投資人要賣出時參考報價）
  賣出價或委賣價（Ask）是銀行"賣出"給投資人的價格（投資人要買進時參考報價）
  */
  double price = (cmd == OP_BUY ? Ask : Bid);
  //--- calculated SL and TP prices must be normalized
  double stoploss = NormalizeDouble((cmd == OP_BUY ? Bid : Ask) + (cmd == OP_BUY ? -1 : 1) * _SL * MinStopLevel * Point,Digits);
  double takeprofit = NormalizeDouble((cmd == OP_BUY ? Bid : Ask) + (cmd == OP_BUY ? 1 : -1) * _SL * _RR * MinStopLevel * Point, Digits);
  color arrowColor = (cmd == OP_BUY ? clrRoyalBlue : clrOrangeRed);
  string cmdName = (cmd == OP_BUY ? "【多】" : "【空】");
  int ticket;

  ticket = OrderSend(_Symbol, cmd, _Lots, price, vSlippage, stoploss, takeprofit, comment, MAGICMA, 0, arrowColor);

  Print(StringFormat("%s 單開倉結果：%d comment=%s", cmdName, ticket, comment));
  Print(StringFormat("open #%d %s %f %s at 3909.31 sl: %f tp: %f %s", ticket, cmdName, _Lots , _Symbol, stoploss, takeprofit, (ticket < 0 ? StringFormat("Err=%d", GetLastError()) : "successfully")));

  return;
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 統計盈利
//+------------------------------------------------------------------+
double SumProfit() {
  double sum = 0;
// 遍歷訂單，關閉全部
  for(int i = 0; i < OrdersTotal(); i++) {
    // 選中倉單，選擇不成功時，跳過本次循環
    if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == false) {
      Print("統計盈利=>注意！選中倉單失敗！序號=[",i,"]");
      continue;
    }
    sum += OrderProfit();
  }
  return sum;
}

//+------------------------------------------------------------------+
//| 平倉，關閉指定交易方向「所有訂單」
//+------------------------------------------------------------------+
void CloseAllOrder(int onOrderType) {
  // OP_BUY , OP_SELL
  // 遍歷訂單，關閉全部
  for(int i = 0; i < OrdersTotal(); i++) {
    // 選中倉單，選擇不成功時，跳過本次循環
    if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == false) {
      Print("自動平倉: 注意！選中倉單失敗！序號=[",i,"]");
      continue;
    }
    //如果 倉單編號不是本系統編號，或者倉單貨幣對不是當前貨幣對時、或選到交易是手動交易訂單，跳過本次循環
    /*if(OrderMagicNumber() != MAGICMA || OrderSymbol()!= _Symbol)
    {
       Print("注意！訂單魔術標記不符！倉單魔術編號=[",OrderMagicNumber(),"]","本EA魔術編號=[",MAGICMA,"]");
       continue;
    }*/

    // 平倉：
    if(OrderType() == onOrderType) {
      RefreshRates();
      // Get current market prices.
      Print("自動平倉: 訂單ticket=[",OrderTicket(),"], 品項=[",OrderSymbol(),"], 手數=[",OrderLots(),"], 交易方向onOrderType=[" + IntegerToString(onOrderType) + "]");
      if(!OrderClose(OrderTicket(), OrderLots(), OrderType() == OP_BUY ? Bid : Ask, 2, White)) Print("自動平倉: 關閉出錯",GetLastError());
      continue;
    }

  }
}
//+------------------------------------------------------------------+
