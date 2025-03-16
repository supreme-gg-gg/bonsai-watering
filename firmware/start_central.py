# Starts a BLE central device that scans for BLE peripherals and connects to them
# Once found the phone app (BLEPeripheral) will attempt to pair and connect
# Sends mock MoistureData to the phone app

import asyncio
import random
import struct
import sys
from bleak import BleakScanner, BleakClient
from bleak.exc import BleakError

# Define UUIDs - these should match the UUIDs used in your phone app
MOISTURE_SERVICE_UUID = "12345678-1234-5678-1234-56789abcdef0"
MOISTURE_CHAR_UUID = "12345678-1234-5678-1234-56789abcdef1"
PHONE_APP_NAME = "BonsaiPeripheral"

# Function to generate mock moisture data
def generate_mock_moisture_data():
    # Mock data: moisture level (0-100%)
    moisture_level = random.randint(0, 100)
    # Pack as binary data - a simple unsigned byte
    return struct.pack("<B", moisture_level)

# Notification callback
def notification_handler(sender, data):
    print(f"Received notification: {data}")

async def scan_and_connect():
    print("Starting BLE Central - Bonsai Watering System")
    
    while True:
        try:
            print("Scanning for BLE peripherals...")
            devices = await BleakScanner.discover(timeout=10.0)
            
            print(f"Found {len(devices)} devices")
            
            # Look for the phone app
            phone_device = None
            for device in devices:
                print(f"Device {device.address}, Name={device.name}")
                if device.name and PHONE_APP_NAME in device.name:
                    print(f"Found phone app: {device.address}")
                    phone_device = device
                    break
            
            # If we found the phone, connect to it
            if phone_device:
                async with BleakClient(phone_device.address) as client:
                    print(f"Connected to {phone_device.name}!")
                    
                    # Discover services and characteristics
                    services = await client.get_services()
                    moisture_char = None
                    
                    for service in services:
                        print(f"Service: {service.uuid}")
                        if service.uuid.lower() == MOISTURE_SERVICE_UUID.lower():
                            for char in service.characteristics:
                                print(f"  Characteristic: {char.uuid}")
                                if char.uuid.lower() == MOISTURE_CHAR_UUID.lower():
                                    moisture_char = char
                    
                    if moisture_char:
                        # Set up notification handler if notifications are supported
                        if "notify" in moisture_char.properties:
                            await client.start_notify(moisture_char.uuid, notification_handler)
                        
                        # Main loop for sending mock moisture data
                        print("Connected! Sending mock moisture data...")
                        while True:
                            try:
                                # Generate and send mock data
                                mock_data = generate_mock_moisture_data()
                                moisture_value = struct.unpack('<B', mock_data)[0]
                                print(f"Sending moisture level: {moisture_value}%")
                                
                                # Write the data to the characteristic
                                await client.write_gatt_char(moisture_char.uuid, mock_data)
                                
                                # Wait before sending the next data
                                await asyncio.sleep(5)
                                
                                # Check if still connected
                                if not client.is_connected:
                                    print("Connection lost")
                                    break
                                    
                            except Exception as e:
                                print(f"Error sending data: {e}")
                                break
                    else:
                        print("Moisture characteristic not found")
            else:
                print("Phone app not found, scanning again...")
                await asyncio.sleep(2)
                
        except BleakError as e:
            print(f"Bluetooth error: {e}")
            await asyncio.sleep(2)
        except KeyboardInterrupt:
            print("\nExiting...")
            return
        except Exception as e:
            print(f"Unexpected error: {e}")
            await asyncio.sleep(2)

def main():
    try:
        asyncio.run(scan_and_connect())
    except KeyboardInterrupt:
        print("\nExiting...")
    finally:
        sys.exit()

if __name__ == "__main__":
    main()