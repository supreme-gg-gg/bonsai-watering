import spidev
import time

class CalibratedMoistureSensor:
    def __init__(self, channel=0, calibration_points=None):
        """Initialize the calibrated moisture sensor.
        
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
        # From the provided data:
        # ~365 raw value (35% sensor reading) → 7.75% water content
        # ~620 raw value (60% sensor reading) → 20% water content
        self.calibration_points = calibration_points or [(220, 3), (365, 7.5), (680, 15.0)]
    
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
    
    def calibrate(self, raw_value):
        """Convert raw sensor value to calibrated water content percentage.
        
        Uses linear interpolation between calibration points.
        """
        # Sort calibration points by raw value
        points = sorted(self.calibration_points)
        
        # Handle values below lowest calibration point
        if raw_value <= points[0][0]:
            return points[0][1]
        
        # Handle values above highest calibration point
        if raw_value >= points[-1][0]:
            return points[-1][1]
        
        # Linear interpolation between calibration points
        for i in range(len(points) - 1):
            if points[i][0] <= raw_value <= points[i+1][0]:
                x0, y0 = points[i]
                x1, y1 = points[i+1]
                
                # Linear interpolation formula: y = y0 + (y1-y0)*(x-x0)/(x1-x0)
                return y0 + (y1 - y0) * (raw_value - x0) / (x1 - x0)
    
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
