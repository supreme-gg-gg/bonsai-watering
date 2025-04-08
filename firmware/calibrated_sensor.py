import spidev
import time
import numpy as np

class CalibratedMoistureSensor:
    def __init__(self, channel=0, calibration_points=None):
        """Initialize the calibrated moisture sensor.
        NOTE: We need to manually determine the saturation percentage (here is 15%)
        
        Args:
            channel: The MCP3008 channel for the sensor (default: 0)
            calibration_points: List of tuples (raw_value, actual_water_content_percent)
                                If None, default calibration from provided data is used
        """
        # Open SPI bus
        self.spi = spidev.SpiDev()
        self.spi.open(0, 0)
        self.spi.max_speed_hz = 1000000
        self.channel = channel
        
        # Default calibration based on provided measurements
        self.calibration_points = calibration_points or [(0,0), (84, 5), (286, 10), (495, 15), (650, 20)]
        
        # Fit a line through calibration points
        x = np.array([point[0] for point in self.calibration_points])
        y = np.array([point[1] for point in self.calibration_points])
        
        # Linear regression: y = mx + b
        self.slope, self.intercept = np.polyfit(x, y, 1)
        print(f"Calibration line: y = {self.slope:.6f}x + {self.intercept:.6f}")
    
    def read_raw(self):
        """Read raw value from the MCP3008 chip."""
        adc = self.spi.xfer2([1, (8 + self.channel) << 4, 0])
        data = ((adc[1] & 3) << 8) + adc[2]
        return data
    
    def read_percent(self):
        """Convert raw value to percentage (0-100%)."""
        raw_value = self.read_raw()
        percent = int(round(raw_value / 10.24))
        return percent
    
    def read_calibrated(self):
        """Read and return calibrated water content percentage."""
        raw_value = self.read_raw()
        return self.calibrate(raw_value)

    def read_calibrated_percent(self) -> int:
        """
        Same as read_calibrated but returns the precentage of the max value
        instead of the calibrated value.
        This is useful for displaying the value as a percentage.
        The max value is assumed to be 100% water content.
        """
        raw_value = self.read_raw()
        abs_percent = self.calibrate(raw_value)
        rel_percent = abs_percent / 15.0 # 15% is the saturation percentage
        return int(round(rel_percent * 100))
    
    def calibrate(self, raw_value):
        """Convert raw sensor value to calibrated water content percentage.
        
        Uses the fitted line equation: water_content = slope * raw_value + intercept
        """
        # Calculate water content using the fitted line
        water_content = self.slope * raw_value + self.intercept
        
        # Ensure output is non-negative (sensors can't report negative water content)
        return max(0, water_content)
    
    def close(self):
        """Close SPI connection."""
        self.spi.close()

def demo():
    """Demonstrate the calibrated sensor."""
    sensor = CalibratedMoistureSensor()
    try:
        print("Press Ctrl+C to stop")
        print("Raw, Percent, Calibrated Water Content (%)")
        while True:
            raw = sensor.read_raw()
            percent = sensor.read_percent()
            calibrated = sensor.read_calibrated()
            print(f"{raw}, {percent}%, {calibrated:.2f}%")
            time.sleep(2)
    except KeyboardInterrupt:
        print("Program stopped by user")
    finally:
        sensor.close()

if __name__ == "__main__":
    demo()
