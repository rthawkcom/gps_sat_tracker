# gps_tracker
Plots GPS satellites on a webpage based on input from a common USB GPS module.

Using a common USB plug in GPS module, data is retrieved from the module and displayed on a webpage using HTML5 Canvas.

There are two parts:  

The first part is "gps-engine.pl" which will read data from "/dev/attyACM0" provided by the GPS module.  It then sets up a listening deamon on the specified port and will dispense the GPS daa.
The second part is "gps.pl" which plots the satellites based on the data obtained from gps-engine.pl via a XHR connection.
