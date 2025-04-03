import RPi.GPIO as GPIO
import Adafruit_DHT 	
import time
import spidev
import matplotlib.pyplot as plt

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

# Initialize lists to store time and moisture data
time_data = []
moisture_data = []

# Initialize the plot
plt.ion()
fig, ax = plt.subplots()
line, = ax.plot(time_data, moisture_data, label="Soil Moisture (%)")
ax.set_xlabel("Time (s)")
ax.set_ylabel("Moisture (%)")
ax.set_title("Soil Moisture Content Over Time")
ax.legend()

start_time = time.time()

try:
    while True:
        # Read the moisture sensor data
        moisture_level = ReadChannel(moisture_channel)
        moisture_percent = ConverttoPercent(moisture_level)

        # Calculate elapsed time
        elapsed_time = time.time() - start_time

        # Append data to lists
        time_data.append(elapsed_time)
        moisture_data.append(moisture_percent)

        # Update the plot
        line.set_xdata(time_data)
        line.set_ydata(moisture_data)
        ax.relim()
        ax.autoscale_view()
        plt.draw()
        plt.pause(0.01)

        # Print out results
        print("--------------------------------------------")
        print("Moisture : {} ({}%)".format(moisture_level, moisture_percent))  

        # Wait before repeating loop
        time.sleep(delay)
except KeyboardInterrupt:
    print("Program stopped by user")
finally:
    # Cleanup GPIO settings
    spi.close()
    plt.ioff()
    plt.show()
