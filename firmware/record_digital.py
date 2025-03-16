import RPi.GPIO as GPIO
import time

GPIO.setmode(GPIO.BCM)
channel = 21

GPIO.setup(channel, GPIO.IN, pull_up_down=GPIO.PUD_UP)

try: 
    while True:
        input_value = GPIO.input(channel)
        print(f"GPIO Pin {channel} value: {input_value}")
        time.sleep(1)

except KeyboardInterrupt:
    print("Program terminated")
    GPIO.cleanup()
