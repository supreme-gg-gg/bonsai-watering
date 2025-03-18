import asyncio
import random
import struct
import sys
import platform
from bleak import BleakScanner, BleakClient
from bleak.exc import BleakError

# Define UUIDs - these should match the UUIDs used in your phone app
MOISTURE_SERVICE_UUID = "12345678-1234-5678-1234-56789abcdef0"
MOISTURE_CHAR_UUID = "12345678-1234-5678-1234-56789abcdef1"
PHONE_APP_NAME = "BonsaiPeripheral"

# Function to generate mock moisture data
def generate_mock_moisture_data():
    moisture_level = random.randint(0, 100)
    return f"Moisture: {moisture_level}%".encode('utf-8')

# Notification callback
def notification_handler(sender, data):
    print(f"Received notification from {sender}: {data}")
    try:
        print(f"Decoded: {data.decode('utf-8')}")
    except:
        print(f"Raw data: {data.hex()}")

async def retry_connect(address, max_attempts=3, delay=2.0):
    """Attempt to connect with retries"""
    for attempt in range(max_attempts):
        try:
            print(f"Connection attempt {attempt+1}/{max_attempts}...")
            client = BleakClient(address)
            await client.connect(timeout=15.0)
            if client.is_connected:
                print("✅ Connected successfully!")
                return client
            print("Failed to connect, retrying...")
        except BleakError as e:
            print(f"Connection error: {e}")
        except Exception as e:
            print(f"Unexpected error: {e}")
        
        # Wait before retrying
        await asyncio.sleep(delay)
    
    return None

async def scan_and_connect():
    """Main function to scan for and connect to the BLE peripheral"""
    print(f"Starting BLE Central on {platform.system()} {platform.release()}")
    print(f"Looking for peripheral named '{PHONE_APP_NAME}'")
    print(f"Service UUID: {MOISTURE_SERVICE_UUID}")
    print(f"Characteristic UUID: {MOISTURE_CHAR_UUID}")
    
    while True:
        try:
            print("\n--------- New Scan Cycle ---------")
            # First scan with increased timeout
            devices = await BleakScanner.discover(timeout=10.0)
            
            print(f"Found {len(devices)} devices")
            
            # Look for the phone app specifically
            phone_device = None
            for device in devices:
                device_name = device.name or "Unknown"
                if device_name == "Unknown" and device.address:
                    print(f"Device {device.address} - Name: Unknown")
                else:
                    print(f"Device {device.address} - Name: {device_name}")
                
                # Check if this is our target device
                if device_name and PHONE_APP_NAME in device_name:
                    print(f"✅ Found target device: {device_name} ({device.address})")
                    phone_device = device
                    break
            
            # If we found the device, attempt to connect
            if phone_device:
                print(f"Attempting to connect to {phone_device.name}...")
                client = await retry_connect(phone_device.address)
                
                if client and client.is_connected:
                    try:
                        # Allow time for services to be discovered
                        print("Connected! Waiting for service discovery...")
                        await asyncio.sleep(2.0)
                        
                        # Attempt to get all services
                        print("Discovering services...")
                        for retry in range(3):
                            try:
                                services = await client.get_services()
                                break
                            except Exception as e:
                                print(f"Service discovery error (attempt {retry+1}/3): {e}")
                                if retry < 2:
                                    print("Retrying service discovery...")
                                    await asyncio.sleep(1.0)
                                else:
                                    print("Failed all service discovery attempts")
                                    services = None
                        
                        # Check if we got services
                        if not services:
                            print("⚠️ No services object returned")
                            await client.disconnect()
                            await asyncio.sleep(5.0)
                            continue
                        
                        # Convert services to a list for easier inspection
                        service_list = list(services)
                        
                        if not service_list:
                            print("⚠️ No services found! Check the iOS app is properly advertising.")
                            print("Disconnecting and retrying in 5 seconds...")
                            await client.disconnect()
                            await asyncio.sleep(5.0)
                            continue
                        
                        # Debug all services and characteristics
                        print("\n--- DISCOVERED SERVICES AND CHARACTERISTICS ---")
                        for service in service_list:
                            print(f"Service: {service.uuid}")
                            for char in service.characteristics:
                                props = ", ".join(char.properties)
                                print(f"  Characteristic: {char.uuid}")
                                print(f"    Properties: {props}")
                                print(f"    Handle: {char.handle}")
                        print("---------------------------------------------\n")
                        
                        # Look for our service by UUID
                        target_service = None
                        for service in service_list:
                            if service.uuid.lower() == MOISTURE_SERVICE_UUID.lower():
                                target_service = service
                                print(f"Found target service: {service.uuid}")
                                break
                        
                        if not target_service:
                            print(f"⚠️ Target service ({MOISTURE_SERVICE_UUID}) not found!")
                            # Try to find any primary services
                            primary_services = [s for s in service_list if hasattr(s, 'primary') and s.primary]
                            if primary_services:
                                print("Available primary services:")
                                for s in primary_services:
                                    print(f" - {s.uuid}")
                            await client.disconnect()
                            await asyncio.sleep(5.0)
                            continue
                        
                        # Look for our characteristic
                        target_char = None
                        for char in target_service.characteristics:
                            if char.uuid.lower() == MOISTURE_CHAR_UUID.lower():
                                target_char = char
                                print(f"Found target characteristic: {char.uuid}")
                                print(f"Properties: {', '.join(char.properties)}")
                                break
                        
                        if not target_char:
                            print(f"⚠️ Target characteristic ({MOISTURE_CHAR_UUID}) not found!")
                            await client.disconnect()
                            await asyncio.sleep(5.0)
                            continue
                        
                        # If we got here, we can interact with the characteristic
                        print("✅ Service and characteristic found!")
                        
                        # Set up notifications if supported by the characteristic
                        """
                        if "notify" in target_char.properties:
                            print("Setting up notifications...")
                            try:
                                await client.start_notify(target_char.uuid, notification_handler)
                                print("Notifications enabled")
                            except Exception as e:
                                print(f"Failed to enable notifications: {e}")
                        """

                        # Try reading the characteristic if supported
                        if "read" in target_char.properties:
                            try:
                                read_value = await client.read_gatt_char(target_char.uuid)
                                print(f"Initial read value: {read_value}")
                                try:
                                    print(f"Decoded: {read_value.decode('utf-8')}")
                                except:
                                    print(f"Raw hex: {read_value.hex()}")
                            except Exception as e:
                                print(f"Failed to read characteristic: {e}")
                        
                        # Main communication loop
                        print("\nStarting communication loop...")
                        for i in range(10):  # Send 10 messages and then reconnect
                            try:
                                if client.is_connected:
                                    # Generate and send mock data
                                    data = generate_mock_moisture_data()
                                    print(f"Sending: {data.decode('utf-8')}")
                                    
                                    # Write the data
                                    await client.write_gatt_char(target_char.uuid, data)
                                    print("✅ Write successful")
                                    
                                    # Wait before sending again
                                    await asyncio.sleep(5.0)
                                else:
                                    print("Connection lost")
                                    break
                            except Exception as e:
                                print(f"Error in communication loop: {e}")
                                break
                        
                        # Clean disconnect
                        print("Communication complete, disconnecting...")
                        await client.disconnect()
                        print("Disconnected cleanly")
                        
                    except Exception as e:
                        print(f"Error during device interaction: {e}")
                        import traceback
                        traceback.print_exc()
                        if client.is_connected:
                            await client.disconnect()
                
                else:
                    print("Could not establish connection to device")
            
            else:
                print(f"Device '{PHONE_APP_NAME}' not found, will scan again")
            
            # Wait before next scan cycle
            await asyncio.sleep(5.0)
                
        except KeyboardInterrupt:
            print("\nUser interrupted, exiting...")
            return
        except Exception as e:
            print(f"Unexpected error in main loop: {e}")
            import traceback
            traceback.print_exc()
            await asyncio.sleep(5.0)

def main():
    try:
        # Set event loop policy for Windows if needed
        if platform.system() == "Windows":
            asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
        
        # Run the main async function
        asyncio.run(scan_and_connect())
    except KeyboardInterrupt:
        print("\nExiting program...")
    finally:
        print("Program terminated")
        sys.exit()

if __name__ == "__main__":
    main()
