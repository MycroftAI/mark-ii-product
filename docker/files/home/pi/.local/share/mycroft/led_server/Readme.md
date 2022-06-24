What is this???


The new version (not yet released as of 6/22) of the SJ201 has
removed the AtTiny processor and gone with I2C interfaces for 
the LEDs and fan. 

In the MarkII code line this device shows up in the Mark2.py 
file as personality SJ201R5, however, this code uses the 
Adafruit neopixel python library to control the LEDs and this
module requires elevated priviliges. 

Rather than run Mycroft services as root this code provides a 
separate mini python webserver which runs as root which solves
this issue. The SJ201r5X.py driver is used to interface Mycroft
with the LEDs using this neopixel server. 

At startup you will need to run the server using elevated
priviliges. For example 

sudo python neopixel_server.py &

Then when the new SJ201 is released simply configure the
driver to use the SJ201r5X LED driver and the LEDs on
the new board will work without having to run Mycroft as
root.

