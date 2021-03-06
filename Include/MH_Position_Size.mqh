//+------------------------------------------------------------------+
//|                                             MH Position Size.mqh |
//|                        Copyright 2017, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property strict
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2010
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex5"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+
//-----------------------------------------------------------------------------------------------------------------------------------------
// CALCULATE POSITION SIZE OR EXIT IF TOO LARGE FOR ACCOUNT
//-----------------------------------------------------------------------------------------------------------------------------------------
//POSITION SIZING ---------------------------------------------------------------
/* It is unclear from Miner whether to use "account equity" or "account balance", as he uses both phrases interchangeably. whereas with MT4 they are different.
On researching, https://forum.mql4.com/58276/page2#851940 it looks like some people are using "account balance". so that's what I will do until I find out more.
 
Miner p.159: The maximum exposure should be a percentage of the **account equity** available.
If the available equity is $20,000, the maximum capital exposure on a trade should be $600 ($20,000 × 3 percent).
Also the maximum capital exposure on all open trades should be $1,200 ($20,000 × 6 percent).

Maximum position size is a function of maximum initial capital exposure per trade unit.
First, calculate the maximum trade capital exposure of 3% of available **account balance**.
Then calculate the capital exposure *per unit* based on the objective entry price and initial protective stop. (The unit could be a futures contract or per share)
Finally, divide the maximum account capital exposure by the trade unit capital exposure to arrive at the maximum position size for the trade.

Maximum Position Size = Available Capital × 3% / Capital Exposure per Unit
Capital Exposure per Unit = difference between Sell(Buy) Stop and Loss Stop

Definitions:
- Tick: A tick is the smallest change of price.
      In currencies a tick is a Point. Price can change by least significant digit (1.23456 -> 1.23457)
      In metals a Tick is still the smallest change but is larger than a point. If price can change from 123.25 to 123.50, you have a TickSize of 0.25 and a point of 0.01. Pip has no meaning.
- Point: A Point is the least significant digit quoted.
      On a 4 digit broker a point (0.0001) = pip (0.0001). [JPY 0.01 == 0.01]
      On a 5 digit broker a point (0.00001) = 1/10 pip (0.00010/10).
- Pip:
      In currencies a pip is defined as 0.0001 (or for JPY 0.01).
      Just because you quote an extra digit doesn't change the value of a pip. (0.0001 == 0.00010) EA's must adjust pips to points (for mq4).
http://gkfxecn.com/en/trade_specs/traders_calculator.html#t1
1 pip is equal to:
   a change in the fourth digit after the decimal point for currency pairs with five digits after the decimal (0.00010);
   a change in the second digit after the decimal point for currency pairs with three digits after the decimal (0.010);
   a change in the second digit after the decimal point for spot silver XAGUSD (0.010);
   a change in the first digit after the decimal point for spot gold XAUUSD (0,10).

This is why you don't use TickValue by itself. Only as a ratio with TickSize. See DeltaValuePerLot()

MODE_TICKSIZE:       Tick *size* in points
                     MODE_TICKSIZE will usually return the same value as MODE_POINT (or Point for the current symbol).
                     However, an example of where to use MODE_TICKSIZE would be as part of a ratio with MODE_TICKVALUE when performing money management calculations which
                     need to take account of the pair and the account currency. The reason I use this ratio is that although TV and TS may constantly be returned as something like
                     7.00 and 0.00001 respectively. I've seen this (intermittently) change to 14.00 and 0.00002 respectively (just example tick values to illustrate).
MODE_TICKVALUE:      Tick *value* in the *deposit* currency.  This is one-point value in the deposit currency.
MODE_POINT:          Point *size* in the *quote* currency. For the current symbol, it is stored in the predefined variable Point

MODE_MINLOT:         Minimum permitted amount of a lot
MODE_MAXLOT:         Maximum permitted amount of a lot
MODE_LOTSIZE:        contract size in the symbol base currency  e.g. EUR for EURUSD and GBP for GBPJPY. But if your account's currency is USD then the lot size in your account's currency will be different for both EURUSD and GBPJPY and will depend on the related exchange rates even though MODE_LOTSIZE is 10000.
MODE_LOTSTEP:        Step for changing lots (is this the increment value?)

Base currency:       The base currency for CHFJPY is Swiss franc, and the price of one lot will be expressed in Swiss francs.
Deposit currency:    Though it is possible to make trades using various currency pairs, the trading result is always written in only one currency - the deposit currency.
                     If the deposit currency is US dollar, profits and losses will be shown in US dollars, if it is euro, they will be, of course, in euros. 
                     You can get information about your deposit currency using the AccountCurrency() function. It can be used to convert the trade results into deposit currency.
Quote currency:

MODE_MARGINREQUIRED: Free margin required to open 1 lot for buying

Just as lot size must be a multiple of lot step
    double  minLot  = MarketInfo(_Symbol, MODE_MINLOT),
            lotStep = MarketInfo(_Symbol, MODE_LOTSTEP),
    lotSize = MathFloor(lotSize/lotStep)*lotStep;
    if (lotSize < minLot) ...
open price must be a multiple of tick size
    double  tickSize = MarketInfo(_Symbol, MODE_TICKSIZE);
    nowOpen = MathRound(nowOpen/tickSize)*tickSize;
*/
double TradeUnit_PositionSize_Get(double CEQuote) //CEQuote capital exposure *per unit* for UK100 is in quote currency
{  LOG(StringFormat("CEQuote = %1.f", CEQuote));
   RefreshRates();                                       // EA  might have been calculating for a long time and needs data refreshing.
   double MaxCEDeposit= AccountEquity() * RiskRatio;     /* Max Capital Exposure for this trade pair in *deposit* currency */
   double MaxCEQuote = Currency_ConvertDepositToQuote(MaxCEDeposit);   /* convert risk available for this trade pair from deposit to quote currency */
   double TULots = MaxCEQuote / CEQuote;                 /* lots per Trade Unit */
   
   return (TULots);
}
//-----------------------------------------------------------------------------------------------------------------------------------------
// Convert deposit to quote currency
//-----------------------------------------------------------------------------------------------------------------------------------------
double Currency_ConvertDepositToQuote(double Deposit)
{  LOG(StringFormat("Deposit = %1.f", Deposit));
   double CA = 1;                         //Currency adjuster ... default exchange rate = 1.0000.
   if (MarketInfo(_Symbol,MODE_TICKSIZE)!=0)
      CA = MarketInfo(_Symbol,MODE_TICKSIZE) / MarketInfo(_Symbol,MODE_TICKVALUE);
// e.g. deposit currency is USD (like in ETX Demo accounts), quote currency of UK100 is in GBP
// e.g. on 4/6/2016 USDGBP = 0.68884, MODE_TICKSIZE = 0.1, and MODE_TICKVALUE = 0.145172, 
// so with UK100 the value of 1 USD = 0.1 / 0.145172 / = 0.68884 GBP

   return (Deposit*CA);
}
//-----------------------------------------------------------------------------------------------------------------------------------------
// Normalise Lots to ensure valid number of lots
//-----------------------------------------------------------------------------------------------------------------------------------------
double Lots_Normalize(double LotsRequired)
{  LOG(StringFormat("LotsRequired = %1.f", LotsRequired));
   double LotStep = MarketInfo(_Symbol, MODE_LOTSTEP);

//#ifdef _DEBUG Print("Lots required = ", LotsRequired, ".  LotStep = ", LotStep); #endif
   LotsRequired = MathRound(LotsRequired/LotStep) * LotStep;   /* ensure LotsRequired is a multiple of LotsRequiredtep */
//#ifdef _DEBUG Print("LotsRequired = MathRound(LotsRequired/LotStep) * LotStep: ", LotsRequired); #endif

//ensure LotsRequired are within min and max allowed
   double MinLot = MarketInfo(_Symbol, MODE_MINLOT);
   double MaxLot = MarketInfo(_Symbol, MODE_MAXLOT);
   if (LotsRequired < MinLot)
   {
      LotsRequired = MinLot;
//#ifdef _DEBUG Print("LotsRequired < MinLot, setting LotsRequired to MinLot: ", LotsRequired); #endif
   }
   else if (LotsRequired > MaxLot)
   {
      LotsRequired = MaxLot;
//#ifdef _DEBUG Print("LotsRequired > MaxLot, setting LotsRequired to MaxLot: ", LotsRequired); #endif
   }
   return(LotsRequired);
}
