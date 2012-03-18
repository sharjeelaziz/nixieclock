// 
// Arduinix 6 bulb 
// 
// This code runs a six bulb setup and displays a prototype clock setup.
// NOTE: the delay is setup for IN-17 nixie bulbs.
//
// by Jeremy Howa
// www.robotpirate.com
// www.arduinix.com
// 2008 
//
// 03/14/2012 Shaji - Added support for GPS and RTC
//

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
#include <SoftwareSerial.h>	// http://arduiniana.org

TinyGPS gps; 
SoftwareSerial serial_gps =  SoftwareSerial(1, 0);  // receive on pin 1

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
#define TIME_DOWN 16

void setup() 
{	
	hourFormat12();

	// RTC Stuff
	setSyncProvider(RTC.get);   // the function to get the time from the RTC
	if (timeStatus() != timeSet) {
	   //Unable to sync with the RTC
	   setTime(2,57,00,17,3,12);
	}
	else {
	   //RTC has set the system time
	}
	//testing omly
	setTime(0,0,0,0,0,0);
	
	// GPS Stuff
	serial_gps.begin(4800);
  	
	//Sets up the time and display controls to be inputs with internal pull-up resistors enabled
	pinMode(TIME_DOWN, INPUT);
	digitalWrite(TIME_DOWN, HIGH);
	
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
	while (serial_gps.available()) {
	  gps.encode(serial_gps.read()); // process gps messages
	}
	
	// Nothing will change until millis() increments by 1000
	if (millis() >= gWaitUntil) {
		gWaitUntil = millis() + 3600000L;   // Make sure we wait for another hour
		time_t gpsTime = 0;
		gpsTime = gpsTimeSync();
		if (0 != gpsTime) {
			RTC.set(gpsTime);
		}
	}

	if (timeStatus() != timeSet) {
		// time not set maybe flash the display
		digitalClockDisplay();
	}
	else {
		digitalClockDisplay();
	}
	
	//manualTimeAdjust();
}

void manualTimeAdjust()
{
	byte timeSelect = 0;

	//Time Set Routine
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

		switchRead = digitalRead(TIME_DOWN);
		if (LOW == switchRead) {
			while (LOW == switchRead) {
				switchRead = digitalRead(TIME_DOWN);
			} // do nothing while the switch is low
			delay(10);
			//subtract from time

		}
	}
}

void digitalClockDisplay()
{
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
	
	int tempHour = hour();
	int tempMin = minute();
	int tempSec = second();
	
	// get the high and low order values for hours, min, seconds.
	lowerHour = tempHour % 10;
	upperHour = tempHour - lowerHour;
	lowerMin = tempMin % 10;
	upperMin = tempMin - lowerMin;
	lowerSecond = tempSec % 10;
	upperSecond = tempSec - lowerSecond;
	
	// get the high and low order values for day, month, year
	lowerDay = day() % 10;
	upperDay = day() - lowerDay;
	lowerMonth = month() % 10;
	upperMonth = month() - lowerMonth;
	
	int yy = year();
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
	int offset = 0;
	// returns time_t from gps date and time with the given offset hours
	tmElements_t tm;
	int year;
	gps.crack_datetime(&year, &tm.Month, &tm.Day, &tm.Hour, &tm.Minute, &tm.Second, NULL, NULL);
	tm.Year = year - 1970; 
	time_t time = makeTime(tm);
	return time + (offset * SECS_PER_HOUR);
}

