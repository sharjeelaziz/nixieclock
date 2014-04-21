#!/usr/bin/python

#   Copyright 2014 Sharjeel Aziz (shaji)
   
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#   
#     http://www.apache.org/licenses/LICENSE-2.0
#   
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

import serial, time, datetime, argparse

parser = argparse.ArgumentParser()
parser.add_argument("-d", "--device", action = "store", default = "/dev/cu.HC-05-DevB", help = "Serial Device (Bluetooth)")
parser.add_argument("-c", "--command", action = "store", default = None, help = "UTC time formatted as yy-mm-dd hh:mm:ss ")
parser.add_argument("-n", "--ntp", action = "store_true", default = False, help = "Set time from NTP. Ignores command string.")

args = parser.parse_args()

serial = serial.Serial(args.device, 9600, timeout = 1)

serial.read(1000)
serial.timeout = 0

if args.ntp:
	print "Setting time using ntp server"
	import ntplib
	c = ntplib.NTPClient()
	r = c.request("pool.ntp.org", version = 3)
	dt = datetime.datetime.utcfromtimestamp(round(r.tx_time))
elif args.command:
	print "Setting time from command %s" % args.command
	dt = datetime.datetime.strptime(args.command, "%y-%m-%d %H:%M:%S")
else:
	print "Setting time from host"
	dt = datetime.datetime.utcnow()
	dt = dt.replace(second = int(round(dt.second + (float(dt.microsecond) / 1000000))), microsecond = 0)

timeCommand = "TIME=%s" % dt.strftime("%y/%m/%d %H:%M:%S")
serial.write(timeCommand)
print "Date and time updated to %s" % dt.isoformat(' ')
serial.close()

