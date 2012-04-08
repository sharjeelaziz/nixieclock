// NiXie Clock based on Arduinix shield with DS1307 RTC and GPS Sync
// 14 March 2012 - Sharjeel Aziz (Shaji)
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
// 
// 08/19/2011 - modded for six bulb board, hours, minutes, seconds by Brad L.
//
// 09/03/2011 - Added Poxin's 12 hour setting for removing 00 from hours when set to 12 hour time
// 11/01/2011 - Fixed second to last crossfading digit error, help from Warcabbit - Brad L.


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
#include <DS1307RTC.h>		// a basic DS1307 library that returns time as a time_t
#include <TinyGPS.h>		// http://arduiniana.org
#include <Timezone.h>		// https://github.com/JChristensen/Timezone

//US Eastern Time Zone (New York, Detroit)
TimeChangeRule usEdt = {"EDT", Second, Sun, Mar, 2, -240};    //UTC - 4 hours
TimeChangeRule usEst = {"EST", First, Sun, Nov, 2, -300};     //UTC - 5 hours
Timezone usEastern(usEdt, usEst);

//If TimeChangeRules are already stored in EEPROM, comment out the three
//lines above and uncomment the line below.
//Timezone usEastern(100);    //assumes rules stored at EEPROM address 100

TimeChangeRule *tcr;        //pointer to the time change rule, use to get TZ abbrev
time_t utc, localTime;

TinyGPS gps; 

long gWaitUntil = 0;

#define TIME_SET 14
#define TIME_UP 15

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

void setup() 
{
	// RTC Stuff
	setSyncProvider(RTC.get);   // the function to get the time from the RTC
	if (timeStatus() != timeSet) {
		setTime(usEastern.toUTC(compileTime()));
		RTC.set(usEastern.toUTC(compileTime()));
	}
	else {
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

	// NOTE: Grounding on virtual pins 14 and 15 (analog pins 0 and 1) will set the Hour and Mins.

	pinMode( TIME_SET, INPUT ); // set the vertual pin 14 (pin 0 on the analog inputs ) 
	digitalWrite(14, HIGH); // set pin 14 as a pull up resistor.

	pinMode( TIME_UP, INPUT ); // set the vertual pin 15 (pin 1 on the analog inputs ) 
	digitalWrite(15, HIGH); // set pin 15 as a pull up resistor.

}

void setSN74141Chips( int num2, int num1 )
{
	int a,b,c,d;

	// set defaults.
	a=0;b=0;c=0;d=0; // will display a zero.

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

long clockHourSet = 1;
long clockMinSet  = 27;

int hourButtonPressed = false;
int minButtonPressed = false;

void loop()     
{
	while (Serial.available()) {
		gps.encode(Serial.read()); // process gps messages
	}

	if (millis() >= gWaitUntil) {
		gWaitUntil = millis() + 10000L; 
		time_t gpsTime = 0;
		gpsTime = gpsTimeSync();
		if (0 != gpsTime) {
			RTC.set(gpsTime);
			gWaitUntil = millis() + 3600000L;   // Make sure we wait for another hour
		}
		else {
			//Gps time not available
		}
	}
	
	// todo
	int hourInput = digitalRead(14);  
	int minInput  = digitalRead(15);

	if( hourInput == 0 ) {
		hourButtonPressed = true;
	}

	if( minInput == 0 ) {
		minButtonPressed = true;	
	}

	if( hourButtonPressed == true && hourInput == 1 ) {
		clockHourSet++;
		hourButtonPressed = false;
	}

	if( minButtonPressed == true && minInput == 1 ) {
		clockMinSet++;
		minButtonPressed = false;
	}


	utc = now();
	localTime = usEastern.toLocal(utc, &tcr);

	int lowerHour = 0;
	int upperHour = 0;
	int lowerMin = 0;
	int upperMin = 0;
	int lowerSecond = 0;
	int upperSecond = 0;

	int lowerDay = 0;
	int upperDay = 0;
	int lowerMonth = 0;
	int upperMonth = 0;
	int lowerYear = 0;
	int upperYear = 0;

	int tempSec = second(localTime);

	// get the high and low order values for hours, min, seconds.
	lowerHour = hour(localTime) % 10;
	upperHour = hour(localTime) - lowerHour;
	lowerMin = minute(localTime) % 10;
	upperMin = minute(localTime) - lowerMin;
	lowerSecond = tempSec % 10;
	upperSecond = tempSec - lowerSecond;

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

	if( upperSecond >= 10 )  {
		upperSecond = upperSecond / 10;
	}
	if( upperMin >= 10 ) {
		upperMin = upperMin / 10;
	}
	if( upperHour >= 10 ) {
		upperHour = upperHour / 10;
	}

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

	numberArray[3] = upperHour;
	numberArray[1] = lowerHour;
	numberArray[5] = upperMin;
	numberArray[0] = lowerMin;
	numberArray[4] = upperSecond;  
	numberArray[2] = lowerSecond;

	// display
	displayFadeNumberString();
}

// gps
time_t gpsTimeSync()
{
	//  returns time if avail from gps, else returns 0
	unsigned long fix_age = 0 ;
	gps.get_datetime(NULL, NULL, &fix_age);
	unsigned long time_since_last_fix;
	if(fix_age < 1000) {
		return gpsTimeToArduinoTime(); // return time only if updated recently by gps
	}  
	return 0;
}

time_t gpsTimeToArduinoTime()
{
	// returns time_t from gps date and time with the given offset hours
	tmElements_t tm;
	int year;
	gps.crack_datetime(&year, &tm.Month, &tm.Day, &tm.Hour, &tm.Minute, &tm.Second, NULL, NULL);
	tm.Year = year - 1970; 
	time_t time = makeTime(tm);
	return time;
}

