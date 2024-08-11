// NiXie Clock based on Arduinix shield with DS1307 RTC and Bluetooth Sync
// 19 April 2014 - Sharjeel Aziz (Shaji)
//
// This work is licensed under the Creative Commons 
// Attribution-ShareAlike 3.0 Unported License. To view 
// a copy of this license, visit 
// http://creativecommons.org/licenses/by-sa/3.0/ or send 
// a letter to Creative Commons, 444 Castro Street, 
// Suite 900, Mountain View, California, 94041, USA.
//
// fading transitions sketch for 4-tube board with default connections.
// based on 6-tube sketch by Emblazed
// 06/16/2011 - 4-tube-itized by Dave B.
// 08/19/2011 - modded for six bulb board, hours, minutes, seconds by Brad L.
// 09/03/2011 - Added Poxin's 12 hour setting for removing 00 from hours when set to 12 hour time
// 11/01/2011 - Fixed second to last crossfading digit error, help from Warcabbit - Brad L.
// 04/19/2014 - Added FlorinC's Bluetooth support


// SN74141 : Truth Table
//D C B A #
//L,L,L,L 0
//L,L,L,H 1
//L,L,H,L 2
//L,L,H,H 3
//L,H,L,L 4
//L,H,L,H 5
//L,H,H,L 6
//L,H,H,H 7
//H,L,L,L 8
//H,L,L,H 9

#include <Time.h>  
#include <Wire.h>  
#include <Timezone.h>		// https://github.com/JChristensen/Timezone
#include <EEPROM.h>

//US Eastern Time Zone (New York, Detroit)
TimeChangeRule usEdt = {"EDT", Second, Sun, Mar, 2, -240};    //UTC - 4 hours
TimeChangeRule usEst = {"EST", First, Sun, Nov, 2, -300};     //UTC - 5 hours
Timezone usEastern(usEdt, usEst);

//If TimeChangeRules are already stored in EEPROM, comment out the three
//lines above and uncomment the line below.
//Timezone usEastern(100);    //assumes rules stored at EEPROM address 100

//pointer to the time change rule, use to get TZ abbrev
TimeChangeRule *tcr;        
time_t utc, localTime;

// receive commands from serial port in this buffer;
char cmdBuffer[30] = {0};
byte nCrtBufIndex = 0;

boolean clockDisplay = true;
byte cmdHour, cmdMinute, cmdSecond, cmdYear, cmdMonth, cmdDay = 0;
byte cmdFirstNumber, cmdSecondNumber, cmdThirdNumber  = 0;

// SN74141 (1)
int ledPin_0_a = 2;                
int ledPin_0_b = 3;
int ledPin_0_c = 4;
int ledPin_0_d = 5;

// SN74141 (2)
int ledPin_1_a = 6;                
int ledPin_1_b = 7;
int ledPin_1_c = 8;
int ledPin_1_d = 9;

// anode pins
int ledPin_a_1 = 10;
int ledPin_a_2 = 11;
int ledPin_a_3 = 12;
int ledPin_a_4 = 13;

void setup() 
{
	// RTC Stuff
	//setSyncProvider(RTC.get);   // the function to get the time from the RTC
	if (timeStatus() != timeSet) {
		setTime(usEastern.toUTC(compileTime()));
		//RTC.set(usEastern.toUTC(compileTime()));
	}

	Serial.begin(9600);

	pinMode(ledPin_0_a, OUTPUT);      
	pinMode(ledPin_0_b, OUTPUT);      
	pinMode(ledPin_0_c, OUTPUT);      
	pinMode(ledPin_0_d, OUTPUT);    

	pinMode(ledPin_1_a, OUTPUT);      
	pinMode(ledPin_1_b, OUTPUT);      
	pinMode(ledPin_1_c, OUTPUT);      
	pinMode(ledPin_1_d, OUTPUT);      

	pinMode(ledPin_a_1, OUTPUT);      
	pinMode(ledPin_a_2, OUTPUT);      
	pinMode(ledPin_a_3, OUTPUT);     
}

void setSN74141Chips( int num2, int num1 )
{
	int a,b,c,d;

	// set defaults.
	a=0;
	b=0;
	c=0;
	d=0;

	// Load the a,b,c,d.. to send to the SN74141 IC (1)
	switch( num1 )
	{
		case 0: a=0;b=0;c=0;d=0;break;
		case 1: a=1;b=0;c=0;d=0;break;
		case 2: a=0;b=1;c=0;d=0;break;
		case 3: a=1;b=1;c=0;d=0;break;
		case 4: a=0;b=0;c=1;d=0;break;
		case 5: a=1;b=0;c=1;d=0;break;
		case 6: a=0;b=1;c=1;d=0;break;
		case 7: a=1;b=1;c=1;d=0;break;
		case 8: a=0;b=0;c=0;d=1;break;
		case 9: a=1;b=0;c=0;d=1;break;
		default: a=1;b=1;c=1;d=1;
		break;
	}  

	// Write to output pins.
	digitalWrite(ledPin_0_d, d);
	digitalWrite(ledPin_0_c, c);
	digitalWrite(ledPin_0_b, b);
	digitalWrite(ledPin_0_a, a);

	// Load the a,b,c,d.. to send to the SN74141 IC (2)
	switch( num2 )
	{
		case 0: a=0;b=0;c=0;d=0;break;
		case 1: a=1;b=0;c=0;d=0;break;
		case 2: a=0;b=1;c=0;d=0;break;
		case 3: a=1;b=1;c=0;d=0;break;
		case 4: a=0;b=0;c=1;d=0;break;
		case 5: a=1;b=0;c=1;d=0;break;
		case 6: a=0;b=1;c=1;d=0;break;
		case 7: a=1;b=1;c=1;d=0;break;
		case 8: a=0;b=0;c=0;d=1;break;
		case 9: a=1;b=0;c=0;d=1;break;
		default: a=1;b=1;c=1;d=1;
		break;
	}

	// Write to output pins
	digitalWrite(ledPin_1_d, d);
	digitalWrite(ledPin_1_c, c);
	digitalWrite(ledPin_1_b, b);
	digitalWrite(ledPin_1_a, a);
}

float fadeIn = 8.0f;
float fadeOut = 8.0f;
float fadeMax = 8.0f;
float fadeStep = 0.4f;
int numberArray[6]={0,0,0,0,0,0};
int currNumberArray[6]={0,0,0,0,0,0};
float numberArrayFadeInValue[6]={0.0f,0.0f,0.0f,0.0f,0.0f,0.0f};
float numberArrayFadeOutValue[6]={8.0f,8.0f,8.0f,8.0f,8.0f,8.0f};

void displayFadeNumberString()
{
	// anode channel 1 - numerals 0,3
	setSN74141Chips(currNumberArray[0],currNumberArray[3]);   
	digitalWrite(ledPin_a_1, HIGH);   
	delay(numberArrayFadeOutValue[4]);
	setSN74141Chips(numberArray[0],numberArray[3]);   
	delay(numberArrayFadeInValue[4]);
	digitalWrite(ledPin_a_1, LOW);

	// anode channel 2 - numerals 1,4
	setSN74141Chips(currNumberArray[1],currNumberArray[4]);   
	digitalWrite(ledPin_a_2, HIGH);   
	delay(numberArrayFadeOutValue[2]);
	setSN74141Chips(numberArray[1],numberArray[4]);   
	delay(numberArrayFadeInValue[2]);
	digitalWrite(ledPin_a_2, LOW);

	// anode channel 3 - numerals 2,5
	setSN74141Chips(currNumberArray[2],currNumberArray[5]);   
	digitalWrite(ledPin_a_3, HIGH);   
	delay(numberArrayFadeOutValue[2]);
	setSN74141Chips(numberArray[2],numberArray[5]);   
	delay(numberArrayFadeInValue[2]);
	digitalWrite(ledPin_a_3, LOW);

	// loop thru and update all the arrays, and fades.
	for( int i = 0 ; i < 6 ; i ++ ) {
		if( numberArray[i] != currNumberArray[i] ) {
			numberArrayFadeInValue[i] += fadeStep;
			numberArrayFadeOutValue[i] -= fadeStep;

			if( numberArrayFadeInValue[i] >= fadeMax ) {
				numberArrayFadeInValue[i] = 0.0f;
				numberArrayFadeOutValue[i] = 7.0f;
				currNumberArray[i] = numberArray[i];
			}
		}
	}  
}

void loop()     
{
	checkBluetoothCommands();
	
	if (clockDisplay) {
		displayTime(now());
	}
	else {
		displayNumber();
	}
	
	if (second(localTime) == 0) {
		antiCathodePoisoning();
	}
	
	displayFadeNumberString();
}

void antiCathodePoisoning()
{
	byte upperDigit = random(10);
	byte lowerDigit = random(10);
	numberArray[3] = upperDigit;
	numberArray[1] = lowerDigit;
	numberArray[5] = upperDigit;
	numberArray[0] = lowerDigit;
	numberArray[4] = upperDigit;  
	numberArray[2] = lowerDigit;
}

void checkBluetoothCommands()
{
	while (Serial.available() > 0) {
		// read the incoming byte;
		char inChar = Serial.read();
		cmdBuffer[nCrtBufIndex++] = inChar;
		if (nCrtBufIndex >= sizeof(cmdBuffer)-1) {
			shiftBufferLeft();
		}
	}
	
	if (0 == strncmp(cmdBuffer, "TIME=", 5) && nCrtBufIndex > 21) {
		// next characters are the date, formatted YY/MM/DD HH:MM:SS
		// This only records the date TIME= actually sets the time
		cmdYear = (cmdBuffer[5]-'0') * 10 + (cmdBuffer[6]-'0');
		cmdMonth = (cmdBuffer[8]-'0') * 10 + (cmdBuffer[9]-'0');
		cmdDay = (cmdBuffer[11]-'0') * 10 + (cmdBuffer[12]-'0');
		cmdHour = (cmdBuffer[14]-'0') * 10 + (cmdBuffer[15]-'0');
		cmdMinute = (cmdBuffer[17]-'0') * 10 + (cmdBuffer[18]-'0');
		cmdSecond = (cmdBuffer[20]-'0') * 10 + (cmdBuffer[21]-'0');
		updateRTCTime();
		resetBuffer();
	}
	else if (0 == strncmp(cmdBuffer, "NUMBER=", 7) && nCrtBufIndex > 14) {
		cmdFirstNumber = (cmdBuffer[7]-'0') * 10 + (cmdBuffer[8]-'0');
		cmdSecondNumber = (cmdBuffer[10]-'0') * 10 + (cmdBuffer[11]-'0');
		cmdThirdNumber = (cmdBuffer[13]-'0') * 10 + (cmdBuffer[14]-'0');
		resetBuffer();
	}
	else if (0 == strncmp(cmdBuffer, "NUMBER ON", 9)) {
		clockDisplay = false;
		resetBuffer();
	}
	else if (0 == strncmp(cmdBuffer, "NUMBER OFF", 10)) {
		clockDisplay = true;
		resetBuffer();
	}
}

void shiftBufferLeft()
{
  for (byte i = 0; i < sizeof(cmdBuffer) - 1; i++) {
	cmdBuffer[i] = cmdBuffer[i + 1];  
  }
  nCrtBufIndex--;
}

void resetBuffer()
{
  for (byte i = 0; i < sizeof(cmdBuffer); i++) {
	cmdBuffer[i] = 0;  
  }
  nCrtBufIndex = 0;
}

void displayNumber()
{
	int lowerHour = 0;
	int upperHour = 0;
	int lowerMin = 0;
	int upperMin = 0;
	int lowerSecond = 0;
	int upperSecond = 0;

	// get the high and low order values for hours, min, seconds.
	lowerHour = cmdFirstNumber % 10;
	upperHour = cmdFirstNumber - lowerHour;
	lowerMin = cmdSecondNumber % 10;
	upperMin = cmdSecondNumber - lowerMin;
	lowerSecond = cmdThirdNumber % 10;
	upperSecond = cmdThirdNumber - lowerSecond;

	if( upperSecond >= 10 )  {
		upperSecond = upperSecond / 10;
	}
	if( upperMin >= 10 ) {
		upperMin = upperMin / 10;
	}
	if( upperHour >= 10 ) {
		upperHour = upperHour / 10;
	}

	// fill in the Number array used to display on the tubes

	numberArray[3] = upperHour;
	numberArray[1] = lowerHour;
	numberArray[5] = upperMin;
	numberArray[0] = lowerMin;
	numberArray[4] = upperSecond;  
	numberArray[2] = lowerSecond;
}

void displayTime(time_t timeDisp)
{
	localTime = usEastern.toLocal(timeDisp, &tcr);
	
	int lowerHour = 0;
	int upperHour = 0;
	int lowerMin = 0;
	int upperMin = 0;
	int lowerSecond = 0;
	int upperSecond = 0;
		
	// get the high and low order values for hours, min, seconds.
	lowerHour = hourFormat12(localTime) % 10;
	upperHour = hourFormat12(localTime) - lowerHour;
	lowerMin = minute(localTime) % 10;
	upperMin = minute(localTime) - lowerMin;
	lowerSecond = second(localTime) % 10;
	upperSecond = second(localTime) - lowerSecond;
	
	if( upperSecond >= 10 )  {
		upperSecond = upperSecond / 10;
	}
	if( upperMin >= 10 ) {
		upperMin = upperMin / 10;
	}
	if( upperHour >= 10 ) {
		upperHour = upperHour / 10;
	}
	
	// fill in the Number array used to display on the tubes
	
	numberArray[3] = upperHour;
	numberArray[1] = lowerHour;
	numberArray[5] = upperMin;
	numberArray[0] = lowerMin;
	numberArray[4] = upperSecond;  
	numberArray[2] = lowerSecond;
}

void displayDate(time_t timeDisp)
{
	localTime = usEastern.toLocal(timeDisp, &tcr);
	
	int lowerDay = 0;
	int upperDay = 0;
	int lowerMonth = 0;
	int upperMonth = 0;
	int lowerYear = 0;
	int upperYear = 0;
			
	// get the high and low order values for day, month, year
	lowerDay = day(localTime) % 10;
	upperDay = day(localTime) - lowerDay;
	lowerMonth = month(localTime) % 10;
	upperMonth = month(localTime) - lowerMonth;
	
	int yy = year(localTime);
	
	if (yy >= 2000) {
		yy = yy - 2000;
	}
	else if (yy >= 1900 && yy < 2000) {
		yy == yy - 1900;
	}
	else { //2012
		yy = 12;
	}
	
	lowerYear = yy % 10;
	upperYear = yy - lowerYear;
		
	if( upperDay >= 10 )  {
		upperDay = upperDay / 10;
	}
	if( upperMonth >= 10 ) {
		upperMonth = upperMonth / 10;
	}
	if( upperYear >= 10 ) {
		upperYear = upperYear / 10;
	}
	
	// fill in the Number array used to display on the tubes
	numberArray[3] = upperMonth;
	numberArray[1] = lowerMonth;
	numberArray[5] = upperDay;
	numberArray[0] = lowerDay;
	numberArray[4] = upperYear;  
	numberArray[2] = lowerYear;
}

void updateRTCTime()
{
	tmElements_t tm;
	// offset from 1970;
	tm.Year = (cmdYear + 2000) - 1970;
	tm.Month = cmdMonth;
	tm.Day = cmdDay;
	tm.Hour = cmdHour;
	tm.Minute = cmdMinute;
	tm.Second = cmdSecond;
	time_t time = makeTime(tm);
	
	//RTC.set(time);
	setTime(time);
}

//Function to return the compile date and time as a time_t value
time_t compileTime(void)
{
#define FUDGE 25        //fudge factor to allow for compile time (seconds, YMMV)

	char *compDate = __DATE__, *compTime = __TIME__, *months = "JanFebMarAprMayJunJulAugSepOctNovDec";
	char chMon[3], *m;
	int d, y;
	tmElements_t tm;
	time_t t;

	strncpy(chMon, compDate, 3);
	chMon[3] = '\0';
	m = strstr(months, chMon);
	tm.Month = ((m - months) / 3 + 1);

	tm.Day = atoi(compDate + 4);
	tm.Year = atoi(compDate + 7) - 1970;
	tm.Hour = atoi(compTime);
	tm.Minute = atoi(compTime + 3);
	tm.Second = atoi(compTime + 6);
	t = makeTime(tm);
	return t + FUDGE;        //add fudge factor to allow for compile time
}
