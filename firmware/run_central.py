import asyncio
import random
import sys
import platform
import subprocess
from record_digital import MoistureSensor
from bleak import BleakScanner, BleakClient
from bleak.exc import BleakError

# Define UUIDs - these should match the UUIDs used in your phone app
MOISTURE_SERVICE_UUID = "12345678-1234-5678-1234-56789abcdef0"
MOISTURE_CHAR_UUID = "12345678-1234-5678-1234-56789abcdef1"
PHONE_APP_NAME = "BonsaiPeripheral"

# Function to generate mock moisture data
def get_moisture_data(sensor: MoistureSensor):
    reading = sensor.get_reading()
    # reading is either 1 or 0
    if reading == 0:
        moisture_level = random.randint(0, 20)
    else:
        moisture_level = random.randint(70, 100)
    return f"Moisture: {moisture_level}%".encode('utf-8')

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
        await asyncio.sleep(delay)
    return None

async def forget_and_retry(address):
    """Forgets the device and retries connection."""
    print(f"Attempting to forget device {address}...")
    try:
        subprocess.run(["bluetoothctl", "remove", address], check=True, capture_output=True)
        print("Device forgotten.")
    except subprocess.CalledProcessError as e:
        print(f"Failed to forget device: {e}")
        return False

    await asyncio.sleep(2.0) # wait before retry.
    return True

async def scan_and_connect(sensor: MoistureSensor):
    """Main function to scan for and connect to the BLE peripheral"""
    print(f"Starting BLE Central on {platform.system()} {platform.release()}")
    print(f"Looking for peripheral named '{PHONE_APP_NAME}'")
    print(f"Service UUID: {MOISTURE_SERVICE_UUID}")
    print(f"Characteristic UUID: {MOISTURE_CHAR_UUID}")

    while True:
        try:
            print("\n--------- New Scan Cycle ---------")
            devices = await BleakScanner.discover(timeout=10.0)
            print(f"Found {len(devices)} devices")

            phone_device = next((device for device in devices if device.name and PHONE_APP_NAME in device.name), None)

            if phone_device:
                print(f"✅ Found target device: {phone_device.name} ({phone_device.address})")
                client = await retry_connect(phone_device.address)

                if client and client.is_connected:
                    try:
                        print("Connected! Discovering services...")
                        await asyncio.sleep(2.0)
                        services = None
                        for retry in range(3):
                            try:
                                services = await client.get_services()
                                break
                            except Exception as e:
                                print(f"Service discovery error (attempt {retry+1}/3): {e}")
                                await asyncio.sleep(1.0)
                        if not services:
                            print("⚠️ Failed all service discovery attempts.")
                            await client.disconnect()

                            if await forget_and_retry(phone_device.address):
                                continue # retry the whole loop after forgetting.

                            await asyncio.sleep(5.0)
                            continue

                        service_list = list(services)
                        print("\n--- DISCOVERED SERVICES AND CHARACTERISTICS ---")
                        for service in service_list:
                            print(f"Service: {service.uuid}")
                            for char in service.characteristics:
                                props = ", ".join(char.properties)
                                print(f"  Characteristic: {char.uuid}\n    Properties: {props}\n    Handle: {char.handle}")
                        print("---------------------------------------------\n")

                        target_service = next((s for s in service_list if s.uuid.lower() == MOISTURE_SERVICE_UUID.lower()), None)
                        if not target_service:
                            print(f"⚠️ Target service ({MOISTURE_SERVICE_UUID}) not found!")
                            await client.disconnect()
                            if await forget_and_retry(phone_device.address):
                                continue
                            await asyncio.sleep(5.0)
                            continue

                        target_char = next((char for char in target_service.characteristics if char.uuid.lower() == MOISTURE_CHAR_UUID.lower()), None)
                        if not target_char:
                            print(f"⚠️ Target characteristic ({MOISTURE_CHAR_UUID}) not found!")
                            await client.disconnect()
                            if await forget_and_retry(phone_device.address):
                                continue
                            await asyncio.sleep(5.0)
                            continue

                        print("✅ Service and characteristic found!")
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

                        print("\nStarting communication loop...")
                        for i in range(10):
                            try:
                                if client.is_connected:
                                    data = get_moisture_data(sensor)
                                    print(f"Sending: {data.decode('utf-8')}")
                                    await client.write_gatt_char(target_char.uuid, data)
                                    print("✅ Write successful")
                                    await asyncio.sleep(5.0)
                                else:
                                    print("Connection lost")
                                    break
                            except Exception as e:
                                print(f"Error in communication loop: {e}")
                                break

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
    sensor = MoistureSensor(21)
    try:
        if platform.system() == "Windows":
            asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
        asyncio.run(scan_and_connect(sensor))
    except KeyboardInterrupt:
        print("\nExiting program...")
    finally:
        print("Program terminated")
        sys.exit()

if __name__ == "__main__":
    main()
