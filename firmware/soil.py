#!/usr/bin/python
import RPi.GPIO as GPIO
import time

GPIO.cleanup()

# GPIO Setup
channel = 26
GPIO.setmode(GPIO.BCM)  # BCM pin numbering
GPIO.setup(channel, GPIO.IN, pull_up_down=GPIO.PUD_UP)  # Input with pull-up resistor

# Callback function for pin state change
def callback(channel):
    if GPIO.input(channel):  # HIGH state
        print("Water Detected!")
    else:  # LOW state
        print("No Water Detected!")

# Set up event detection on the channel (both rising and falling edges)
GPIO.add_event_detect(channel, GPIO.BOTH, bouncetime=300)  # Detect both rising and falling edges
GPIO.add_event_callback(channel, callback)  # Assign the callback function to be called on state change

try:
    # Infinite loop to keep the script running
    while True:
        time.sleep(1)

except KeyboardInterrupt:
    print("Program terminated by user")
    GPIO.cleanup()  # Clean up GPIO on exit

