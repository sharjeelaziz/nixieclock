
//Ardunix
// fading transitions sketch for 4-tube board with default connections.
// based on 6-tube sketch by Emblazed
// 06/16/2011 - 4-tube-itized by Dave B.
// 08/19/2011 - modded for six bulb board, hours, minutes, seconds by Brad L.
// 09/03/2011 - Added Poxin's 12 hour setting for removing 00 from hours when set to 12 hour time
// 11/01/2011 - Fixed second to last crossfading digit error, help from Warcabbit - Brad L.
// 04/19/2014 - Added FlorinC's Bluetooth support
// RTC - Based on work by Sebastian Romero @sebromero
// Led Matrix based on https://github.com/eremef/aur4_clock.git

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

#include <I2C_RTC.h>

//static DS1307 RTC;
static DS3231 RTC;
//static PCF8523 RTC;
//static PCF8563 RTC;
//static MCP7940 RTC;

//Include the NTP library
#include <NTPClient.h>

#if defined(ARDUINO_PORTENTA_C33)
#include <WiFiC3.h>
#elif defined(ARDUINO_UNOWIFIR4)
#include <WiFiS3.h>
#endif

#include "led-matrix.h"
#include "Arduino_LED_Matrix.h"

#include <WiFiUdp.h>
#include "d:\dev\wifi.h"

#define TIMEZONE_OFFSET_HOURS 5
#define TIMEZONE_BEHIND_UTC 1 // 1 if behind 0 if ahead

#define ORIENTATION 1 

byte currentFrame[NO_OF_ROWS][NO_OF_COLS];
byte rotatedFrame[NO_OF_ROWS][NO_OF_COLS];

position first = {5, 0}; // position of first digit
position second = {0, 0}; // etc.
position third = {5, 7};
position fourth = {0, 7};

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

unsigned long previousMillis = 0UL;
unsigned long ntpInterval = 1200000UL; //20 minutes

char ssid[] = WIFI_SSID;    // your network SSID (name)
char pass[] = WIFI_PASS;    // your network password (use for WPA, or use as key for WEP)

int wifiStatus = WL_IDLE_STATUS;
WiFiUDP Udp; // A UDP instance to let us send and receive packets over UDP

NTPClient timeClient(Udp, "192.168.70.156", 0, ntpInterval);

ArduinoLEDMatrix matrix;

void setDigit(position digitPosition, const byte digit[][5]){
  for(byte r = 0; r < 3; r++){
    for(byte c = 0; c < 5; c++){
      currentFrame[r+digitPosition.row][c+digitPosition.col] = digit[r][c];
    }
  }
}

void rotateFrame() {
  for(byte r = 0; r < NO_OF_ROWS; r++){
    for(byte c = 0; c < NO_OF_COLS; c++){
      rotatedFrame[r][c] = currentFrame[NO_OF_ROWS-1-r][NO_OF_COLS-1-c];
    }
  }
  memcpy(currentFrame, rotatedFrame, sizeof rotatedFrame);
}

void printWifiStatus() {
  // print the SSID of the network you're attached to:
  Serial.print("SSID: ");
  Serial.println(WiFi.SSID());

  // print your board's IP address:
  IPAddress ip = WiFi.localIP();
  Serial.print("IP Address: ");
  Serial.println(ip);

  // print the received signal strength:
  long rssi = WiFi.RSSI();
  Serial.print("signal strength (RSSI):");
  Serial.print(rssi);
  Serial.println(" dBm");
}

void connectToWiFi() {
  // check for the WiFi module:
  if (WiFi.status() == WL_NO_MODULE) {
    Serial.println("Communication with WiFi module failed!");
    // don't continue
    while (true);
  }

  String fv = WiFi.firmwareVersion();
  if (fv < WIFI_FIRMWARE_LATEST_VERSION) {
    Serial.println("Please upgrade the firmware");
  }

  // attempt to connect to WiFi network:
  while (wifiStatus != WL_CONNECTED) {
    Serial.print("Attempting to connect to SSID: ");
    Serial.println(ssid);
    // Connect to WPA/WPA2 network. Change this line if using open or WEP network:
    wifiStatus = WiFi.begin(ssid, pass);

    // wait 10 seconds for connection:
    delay(10000);
  }

  Serial.println("Connected to WiFi");
  printWifiStatus();
}

bool isDaylightSavingTime(int year, int month, int day, int hour) {
  
  // Calculate the second Sunday in March
  int secondSundayMarch = 14 - (1 + ((year * 5) / 4)) % 7;
  
  // Calculate the first Sunday in November
  int firstSundayNovember = 7 - ((year + year / 4) % 7);

  // Check if the current date is within DST period
  if (month > 3 && month < 11) {
    return true; // April to October is within DST
  }
  if (month == 3) {
    if (day > secondSundayMarch || (day == secondSundayMarch && hour >= 2)) {
      return true;
    }
  }
  if (month == 11) {
    if (day < firstSundayNovember || (day == firstSundayNovember && hour < 2)) {
      return true;
    }
  }
  return false;
}

void setSN74141Chips( int num2, int num1 ) {

	int a,b,c,d;

	// set defaults
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
	switch( num2 ) {
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

void displayFadeNumberString() {

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
		if ( numberArray[i] != currNumberArray[i] ) {
			numberArrayFadeInValue[i] += fadeStep;
			numberArrayFadeOutValue[i] -= fadeStep;

			if ( numberArrayFadeInValue[i] >= fadeMax ) {
				numberArrayFadeInValue[i] = 0.0f;
				numberArrayFadeOutValue[i] = 7.0f;
				currNumberArray[i] = numberArray[i];
			}
		}
	}  
}

void antiCathodePoisoning() {

	byte upperDigit = random(10);
	byte lowerDigit = random(10);
	numberArray[3] = upperDigit;
	numberArray[1] = lowerDigit;
	numberArray[5] = upperDigit;
	numberArray[0] = lowerDigit;
	numberArray[4] = upperDigit;  
	numberArray[2] = lowerDigit;
}

void displayNumber() {

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

	if ( upperSecond >= 10 )  {
		upperSecond = upperSecond / 10;
	}
	if ( upperMin >= 10 ) {
		upperMin = upperMin / 10;
	}
	if ( upperHour >= 10 ) {
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

void displayTime(int hour, int minutes, int seconds) {
	int lowerHour = 0;
	int upperHour = 0;
	int lowerMin = 0;
	int upperMin = 0;
	int lowerSecond = 0;
	int upperSecond = 0;
		
	// get the high and low order values for hours, min, seconds.
	lowerHour = hour % 10;
	upperHour = hour - lowerHour;
	lowerMin = minutes % 10;
	upperMin = minutes - lowerMin;
	lowerSecond = seconds % 10;
	upperSecond = seconds - lowerSecond;
	
	if ( upperSecond >= 10 )  {
		upperSecond = upperSecond / 10;
	}
	if ( upperMin >= 10 ) {
		upperMin = upperMin / 10;
	}
	if ( upperHour >= 10 ) {
		upperHour = upperHour / 10;
	}
	
	// fill in the Number array used to display on the tubes
	
	numberArray[3] = upperHour;
	numberArray[1] = lowerHour;
	numberArray[5] = upperMin;
	numberArray[0] = lowerMin;
	numberArray[4] = upperSecond;  
	numberArray[2] = lowerSecond;

  String alphaHour = (String) hour;
  if (alphaHour.length() == 1){
    alphaHour = "0" + alphaHour;
  }

  String alphaMinutes = (String) minutes;
  if (alphaMinutes.length() == 1){
    alphaMinutes = "0" + alphaMinutes;
  }

  setDigit(first, digits[alphaHour.substring(0,1).toInt()]);
  setDigit(second, digits[alphaHour.substring(1).toInt()]);
  setDigit(third, digits[alphaMinutes.substring(0,1).toInt()]);
  setDigit(fourth, digits[alphaMinutes.substring(1).toInt()]);
  if (ORIENTATION == 1){
    rotateFrame();
  } 
  matrix.renderBitmap(currentFrame, NO_OF_ROWS, NO_OF_COLS); 
}

void displayDate(int day, int month, int year) {	

	int lowerDay = 0;
	int upperDay = 0;
	int lowerMonth = 0;
	int upperMonth = 0;
	int lowerYear = 0;
	int upperYear = 0;
			
	// get the high and low order values for day, month, year
	lowerDay = day % 10;
	upperDay = day - lowerDay;
	lowerMonth = month % 10;
	upperMonth = month - lowerMonth;
	
	if (year >= 2000) {
		year = year - 2000;
	}
	else if (year >= 1900 && year < 2000) {
		year == year - 1900;
	}
	else { //2012
		year = 12;
	}
	
	lowerYear = year % 10;
	upperYear = year - lowerYear;
		
	if ( upperDay >= 10 )  {
		upperDay = upperDay / 10;
	}
	if ( upperMonth >= 10 ) {
		upperMonth = upperMonth / 10;
	}
	if ( upperYear >= 10 ) {
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

void updateTime(auto timeZoneOffsetHours) {

  yield();  
  
  Serial.println("\nStarting connection to server...");
  
  timeClient.update();

  if (timeClient.isTimeSet()) {
    auto unixTime = timeClient.getEpochTime();
    if (0 == TIMEZONE_BEHIND_UTC) {
      unixTime = unixTime + (timeZoneOffsetHours * 3600);
    }
    else {
      unixTime = unixTime - (timeZoneOffsetHours * 3600);
    }
    RTC.setEpoch(unixTime);
    Serial.print("Unix time = ");
    Serial.println(unixTime);
      // Retrieve the date and time from the RTC and print them
    Serial.print(RTC.getHours());
    Serial.print(":");
    Serial.print(RTC.getMinutes());
    Serial.print(":");
    Serial.print(RTC.getSeconds());
  }
}

void setup() {

  Serial.begin(9600);
  while (!Serial);

  auto timeZoneOffsetHours = TIMEZONE_OFFSET_HOURS;

  RTC.begin();
  connectToWiFi();
  timeClient.begin();
  
  updateTime(timeZoneOffsetHours);
  
  if (isDaylightSavingTime(RTC.getYear(), RTC.getMonth(), RTC.getDay(), RTC.getHours())) {  
    timeZoneOffsetHours = TIMEZONE_OFFSET_HOURS - 1;
    updateTime(timeZoneOffsetHours);
  }

  //ardunix
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
  
  matrix.begin(); 
}

void loop() {

  auto timeZoneOffsetHours = TIMEZONE_OFFSET_HOURS;
  
  unsigned long currentMillis = millis();
  
  if (currentMillis - previousMillis > ntpInterval ) {
    if (isDaylightSavingTime(RTC.getYear(), RTC.getMonth(), RTC.getDay(), RTC.getHours())) {  
      timeZoneOffsetHours = TIMEZONE_OFFSET_HOURS - 1;
    } 
    updateTime(timeZoneOffsetHours);
    previousMillis = currentMillis;
  }

  displayTime(RTC.getHours(), RTC.getMinutes(), RTC.getSeconds());
	if (RTC.getSeconds() == 0) {
	    antiCathodePoisoning();
	}
  displayFadeNumberString();
}

