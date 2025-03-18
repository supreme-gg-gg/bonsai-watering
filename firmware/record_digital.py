import RPi.GPIO as GPIO
import time

class MoistureSensor:

    def __init__(self, channel):
        GPIO.setmode(GPIO.BCM)
        self.channel = channel
        GPIO.setup(self.channel, GPIO.IN, pull_up_down=GPIO.PUD_UP)

    def get_reading(self) -> int:
        input_value = GPIO.input(self.channel)
        print(f"GPIO Pin {self.channel} value: {input_value}")
        return input_value

    def __del__(self):
        GPIO.cleanup()


if __name__ == "__main__":
    sensor = MoistureSensor(21)

    try: 
        while True:
            val = sensor.get_reading()
            print(val)
            time.sleep(1)

    except KeyboardInterrupt:
        print("Program terminated")

