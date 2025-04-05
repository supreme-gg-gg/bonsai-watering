import time
from bluepy.btle import Peripheral, UUID, DefaultDelegate
import struct
import random

# Define UUIDs for our service and characteristic
# Using standard base UUID format with our custom values
SENSOR_SERVICE_UUID = UUID("12345678-1234-5678-1234-56789abcdef0")
MOISTURE_CHAR_UUID = UUID("12345678-1234-5678-1234-56789abcdef1")

class MoistureDataDelegate(DefaultDelegate):
    def __init__(self):
        DefaultDelegate.__init__(self)
        
    def handleNotification(self, cHandle, data):
        print(f"Notification from handle {cHandle}: {data}")

class BonsaiPeripheral(Peripheral):
    def __init__(self):
        Peripheral.__init__(self)
        
        # Set up the peripheral
        self.setDelegate(MoistureDataDelegate())
        print("Setting up BLE peripheral...")
        
        try:
            # Add service
            self.service = self.addService(SENSOR_SERVICE_UUID)
            
            # Add MoistureData characteristic
            self.moisture_data_char = self.service.addCharacteristic(
                MOISTURE_CHAR_UUID,
                ["read", "notify"]  # Properties
            )
            self.moisture_data_char.addDescriptor(
                UUID("2901"), "Moisture Data"
            )
            
            # Start advertising
            self.advertise()
            
        except Exception as e:
            print(f"Error setting up peripheral: {e}")
            self.disconnect()
            raise e
    
    def advertise(self):
        """Start advertising the peripheral"""
        print("Starting advertisement...")
        self.advertiseService(SENSOR_SERVICE_UUID)
        
    def update_moisture_data(self, moisture_value):
        """Update the MoistureData characteristic with new value"""
        try:
            # Convert value to bytes
            data = str(moisture_value).encode()
            
            # Write the data to the characteristic
            self.moisture_data_char.write(data)
            
            # Notify connected clients
            if self.moisture_data_char.getHandle():
                self.writeCharacteristic(
                    self.moisture_data_char.getHandle(), 
                    data,
                    withResponse=True
                )
            
            print(f"Moisture data sent: {moisture_value}%")
            return True
            
        except Exception as e:
            print(f"Error updating data: {e}")
            return False

def generate_moisture_data():
    """Generate random moisture value between 0-100"""
    return random.randint(0, 100)

def main():
    peripheral = None
    
    try:
        # Create and start the peripheral
        peripheral = BonsaiPeripheral()
        print("BLE Peripheral started")
        print("Waiting for connections...")
        
        # Main loop to update data
        while True:
            # Generate new moisture data
            moisture = generate_moisture_data()
            
            # Update the characteristic
            peripheral.update_moisture_data(moisture)
            
            # Wait before sending the next update
            time.sleep(5)
                
    except KeyboardInterrupt:
        print("\nStopping BLE peripheral...")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        if peripheral:
            peripheral.disconnect()
            print("BLE peripheral stopped")

if __name__ == "__main__":
    main()