import RPi.GPIO as GPIO
import Adafruit_DHT 	
import time
import spidev

# Open SPI bus
spi = spidev.SpiDev()
spi.open(0,0)
spi.max_speed_hz=1000000

# Function to read SPI data from MCP3008 chip
# Channel must be an integer 0-7
def ReadChannel(channel):
    adc = spi.xfer2([1,(8+channel)<<4,0])
    data = ((adc[1]&3) << 8) + adc[2]
    return data


def ConverttoPercent(data):
    percent = int(round(data/10.24))
    return percent

# Define sensor channel (on MCP3008)
moisture_channel  = 0

# Define delay between readings
delay = 2

try:
    while True:
        # Read the moisture sensor data
        moisture_level = ReadChannel(moisture_channel)
        moisture_percent = ConverttoPercent(moisture_level)

        # Print out results
        print("--------------------------------------------")
        print("Moisture : {} ({}%)".format(moisture_level,moisture_percent))  

        # Wait before repeating loop
        time.sleep(delay)
except KeyboardInterrupt:
    print("Program stopped by user")
finally:
    # Cleanup GPIO settings
    GPIO.cleanup()
    spi.close()
    print("GPIO cleaned up and SPI closed")
