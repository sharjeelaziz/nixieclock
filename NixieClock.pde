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
// This code runs a six bulb setup and displays a prototype clock setup.
// NOTE: the delay is setup for IN-17 nixie bulbs.
//
// by Jeremy Howa
// www.robotpirate.com
// www.arduinix.com
// 2008 
//


// SN74141 : Truth Table
// D C B A #
// L,L,L,L 0
// L,L,L,H 1
// L,L,H,L 2
// L,L,H,H 3
// L,H,L,L 4
// L,H,L,H 5
// L,H,H,L 6
// L,H,H,H 7
// H,L,L,L 8
// H,L,L,H 9


#include <Time.h>  
#include <Wire.h>  
#include <DS1307RTC.h>		// a basic DS1307 library that returns time as a time_t
#include <TinyGPS.h>		// http://arduiniana.org
#include <SoftwareSerial.h>	// http://arduiniana.org
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
SoftwareSerial serialGps =  SoftwareSerial(16, 17);  // receive on pin 1

// SN74141 (1)
int gLedPin_0_a = 2;                
int gLedPin_0_b = 3;
int gLedPin_0_c = 4;
int gLedPin_0_d = 5;

// SN74141 (2)
int gLedPin_1_a = 6;                
int gLedPin_1_b = 7;
int gLedPin_1_c = 8;
int gLedPin_1_d = 9;

// anode pins
int gLedPin_a_1 = 10;
int gLedPin_a_2 = 11;
int gLedPin_a_3 = 12;
int gLedPin_a_4 = 13;

long gWaitUntil = 0;
  
#define TIME_SET 14
#define TIME_UP 15

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
	Serial.begin(9600);
	Serial.println("Waiting for GPS time ... ");

	hourFormat12();

	// RTC Stuff
	setSyncProvider(RTC.get);   // the function to get the time from the RTC
	if (timeStatus() != timeSet) {
	   Serial.println("Unable to sync with the RTC");
	   setTime(usEastern.toUTC(compileTime()));
	}
	else {
	   Serial.println("RTC has set the system time");
	}
	
	// GPS Stuff
	serialGps.begin(9600);
  	
	//Sets up the time and display controls to be inputs with internal pull-up resistors enable
	pinMode(TIME_UP, INPUT);
	digitalWrite(TIME_UP, HIGH);
	
	pinMode(TIME_SET, INPUT);
	digitalWrite(TIME_SET, HIGH);
	
	
	pinMode(gLedPin_0_a, OUTPUT);      
	pinMode(gLedPin_0_b, OUTPUT);      
	pinMode(gLedPin_0_c, OUTPUT);      
	pinMode(gLedPin_0_d, OUTPUT);    
	
	pinMode(gLedPin_1_a, OUTPUT);      
	pinMode(gLedPin_1_b, OUTPUT);      
	pinMode(gLedPin_1_c, OUTPUT);      
	pinMode(gLedPin_1_d, OUTPUT);      
	
	pinMode(gLedPin_a_1, OUTPUT);      
	pinMode(gLedPin_a_2, OUTPUT);      
	pinMode(gLedPin_a_3, OUTPUT);      
  
}

void setSN74141(int icIndex, int displayNumber)
{  
	int a = 0;
	int b = 0;
	int c = 0;
	int d = 0; // will display a zero.
	
	// Load the a,b,c,d.. to send to the SN74141 IC (1)
	switch( displayNumber ) {
	case 0: 
		break;
	case 1: 
		a = 1; 
		break;
	case 2: 
		b = 1; 
		break;
	case 3: 
		a = 1;
		b = 1; 
		break;
	case 4: 
		c = 1; 
		break;
	case 5: 
		a = 1;
		c = 1; 
		break;
	case 6: 
		b = 1;
		c = 1; 
		break;
	case 7: 
		a = 1;
		b = 1;
		c = 1; 
		break;
	case 8: 
		d = 1; 
		break;
	case 9: 
		a = 1;
		d = 1; 
		break;
	default: 
		a = 1;
		b = 1;
		c = 1;
		d = 1;
		break;
	}
	    
	if (0 == icIndex) { // IC1
		// Write to output pins.
		digitalWrite(gLedPin_0_d, d);
		digitalWrite(gLedPin_0_c, c);
		digitalWrite(gLedPin_0_b, b);
		digitalWrite(gLedPin_0_a, a);
	}
	else { // IC2
		// Write to output pins.
		digitalWrite(gLedPin_1_d, d);
		digitalWrite(gLedPin_1_c, c);
		digitalWrite(gLedPin_1_b, b);
		digitalWrite(gLedPin_1_a, a);
	}

}

void displayNumberSet( int anod, int num1, int num2 ) 
{
	int anodPin;
	anodPin = gLedPin_a_1; 
  
	// select which anod to fire.
	switch( anod ) {
    	case 0:    anodPin =  gLedPin_a_1;    break;
    	case 1:    anodPin =  gLedPin_a_2;    break;
    	case 2:    anodPin =  gLedPin_a_3;    break;
    }  
  
	// send to the SN74141 IC (1)
	setSN74141(0, num2);
	// send to the SN74141 IC (2)
	setSN74141(1, num1);
    
    // Turn on this anod.
    digitalWrite(anodPin, HIGH);   
    
    // Delay
    delay(3);
    
    // Shut off this anod.
    digitalWrite(anodPin, LOW);
}


void loop() 
{
	while (serialGps.available()) {
	  gps.encode(serialGps.read()); // process gps messages
	}
	
	// Nothing will change until millis() increments by 1000
	if (millis() >= gWaitUntil) {
		//gWaitUntil = millis() + 3600000L;   // Make sure we wait for another hour
		gWaitUntil = millis() + 10000L;
		time_t gpsTime = 0;
		gpsTime = gpsTimeSync();
		if (0 != gpsTime) {
			Serial.println("Got time from gps");
			RTC.set(gpsTime);
		}
		else {
			Serial.println("Gps time not available");
		}
	}

	if (timeStatus() != timeSet) {
		// time not set maybe flash the display
		digitalClockDisplay();
	}
	else {
		digitalClockDisplay();
	}
	digitalClockDisplay2();

	
	//manualTimeAdjust();
	
	// test code
	bool newData = false;
	unsigned long chars;
	unsigned short sentences, failed;
	
	// For one second we parse GPS data and report some key values
	for (unsigned long start = millis(); millis() - start < 1000;)
	{
	  while (serialGps.available())
	  {
		char c = serialGps.read();
		// Serial.write(c); // uncomment this line if you want to see the GPS data flowing
		if (gps.encode(c)) // Did a new valid sentence come in?
		  newData = true;
	  }
	}
	
	if (newData)
	{
	  float flat, flon;
	  unsigned long age;
	  gps.f_get_position(&flat, &flon, &age);
	  Serial.print("LAT=");
	  Serial.print(flat == TinyGPS::GPS_INVALID_F_ANGLE ? 0.0 : flat, 6);
	  Serial.print(" LON=");
	  Serial.print(flon == TinyGPS::GPS_INVALID_F_ANGLE ? 0.0 : flon, 6);
	  Serial.print(" SAT=");
	  Serial.print(gps.satellites() == TinyGPS::GPS_INVALID_SATELLITES ? 0 : gps.satellites());
	  Serial.print(" PREC=");
	  Serial.print(gps.hdop() == TinyGPS::GPS_INVALID_HDOP ? 0 : gps.hdop());
	}
	
	gps.stats(&chars, &sentences, &failed);
	Serial.print(" CHARS=");
	Serial.print(chars);
	Serial.print(" SENTENCES=");
	Serial.print(sentences);
	Serial.print(" CSUM ERR=");
	Serial.println(failed);
	
	//end test code
}

void manualTimeAdjust()
{
	byte timeSelect = 0;

	// time Set Routine
	boolean switchRead = 1;
	switchRead = digitalRead(TIME_SET);

	if (LOW == switchRead) {
		while (LOW == switchRead) {
			switchRead = digitalRead(TIME_SET);
		} //do nothing while the switch is low

		delay(10);
		timeSelect = ((timeSelect + 1) % 7);
	 }

	 // set hours
	 if (1 == timeSelect) {

		switchRead = digitalRead(TIME_UP);
		if (LOW == switchRead) {
		 	while (LOW == switchRead) {
		 		switchRead = digitalRead(TIME_UP);
		 	} // do nothing while the switch is low
		 	delay(10);
		 	// add to time
		}
	}
}

void digitalClockDisplay2()
{
	
	utc = now();
	localTime = usEastern.toLocal(utc, &tcr);
	
  	// digital clock display of the time
  	Serial.print(hour());
  	printDigits(minute());
  	printDigits(second());
  	Serial.print(" ");
  	Serial.print(day());
  	Serial.print(" ");
  	Serial.print(month());
  	Serial.print(" ");
  	Serial.print(year()); 
  	Serial.println(); 

  	// digital clock display of the local time
  	Serial.print(hour(localTime));
  	printDigits(minute(localTime));
  	printDigits(second(localTime));
  	Serial.print(" ");
  	Serial.print(day(localTime));
  	Serial.print(" ");
  	Serial.print(month(localTime));
  	Serial.print(" ");
  	Serial.print(year(localTime)); 
  	Serial.println(); 

}

void printDigits(int digits)
{
  // utility function for digital clock display: prints preceding colon and leading 0
  Serial.print(":");
  if(digits < 10)
	Serial.print('0');
  Serial.print(digits);
}

void digitalClockDisplay()
{
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

	// bank 1 (bulb 0,3)
	displayNumberSet(0, lowerMin, upperHour);
	
	// bank 2 (bulb 1,4)
	displayNumberSet(1, lowerHour, upperSecond);   
	
	// bank 3 (bulb 2,5)
	displayNumberSet(2, lowerSecond, upperMin); 
		
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

