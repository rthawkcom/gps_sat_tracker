# gps_sat_tracker
Tracks GPS satellites in real time and plots their location in space on a webpage HTML5 canvas, based on input from a common USB GPS module such as this one: 

https://www.amazon.com/gp/product/B01EROIUEW/

This actually tracks their location in real time.  It does NOT use TLE data in an attempt to guess where they might be.  It will also return precision time based on satellite data, so could also be used for an NTP server.

There are two parts:  

The first part is "gps-engine.pl" which will read data from "/dev/attyACM0" provided by the GPS module.  It then sets up a listening deamon on the specified port and will dispense the GPS daa.
The second part is "gps.pl" which sits on your webserver and plots the satellites position based on the data obtained from gps-engine.pl via a XHR connection.

gps_engine.pl which dispenses data can exist on the local webserver or a seperate remote located outside where the GPS module can better be exposed to the open sky.


