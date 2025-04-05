import asyncio
import logging
import sys
from bleak import BleakScanner, BleakClient

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

MOISTURE_SERVICE_UUID = "12345678-1234-5678-1234-56789abcdef0"
MOISTURE_CHAR_UUID = "12345678-1234-5678-1234-56789abcdef1"
SERVER_NAME = "BonsaiPeripheral"

async def notification_handler(sender, data):
    """Handle incoming notifications/indications"""
    logger.info(f"Received data: {data}")
    # Display as string if possible
    try:
        value_str = data.decode('utf-8')
        logger.info(f"As string: {value_str}")
    except:
        pass

async def find_ble_device():
    """Find our BLE device by name or let the user select from available devices"""
    logger.info(f"Scanning for BLE devices...")
    devices = await BleakScanner.discover()
    
    # Try to find by name first
    for device in devices:
        if device.name and SERVER_NAME in device.name:
            logger.info(f"Found device by name: {device.name} ({device.address})")
            return device
            
    # If we can't find by name, check services if available
    for device in devices:
        logger.debug(f"Device: {device.name or 'Unknown'} ({device.address})")
        
    # Let the user select from available devices
    if devices:
        print("\nAvailable devices:")
        for i, device in enumerate(devices):
            print(f"{i}: {device.name or 'Unknown'} ({device.address})")
        
        choice = input("\nEnter device number to connect (or q to quit): ")
        if choice.lower() == 'q':
            return None
        try:
            return devices[int(choice)]
        except (IndexError, ValueError):
            logger.error("Invalid selection")
            return None
    
    return None

async def connect_to_device(device):
    """Connect to the device and interact with it"""
    logger.info(f"Connecting to {device.name or 'Unknown'} ({device.address})...")
    
    async with BleakClient(device) as client:
        logger.info("Connected!")
        
        # Check services
        for service in client.services:
            logger.info(f"Service: {service.uuid}")
            for char in service.characteristics:
                logger.info(f"  Characteristic: {char.uuid}")
                logger.info(f"    Properties: {char.properties}")
        
        # Check if our service and characteristic exist
        if MOISTURE_SERVICE_UUID.lower() not in [s.uuid.lower() for s in client.services]:
            logger.error(f"Service {MOISTURE_SERVICE_UUID} not found!")
            return
            
        try:
            # Read current value
            value = await client.read_gatt_char(MOISTURE_CHAR_UUID)
            logger.info(f"Current value: {value}")
            
            # Set up notification handler for indications/notifications
            await client.start_notify(MOISTURE_CHAR_UUID, notification_handler)
            logger.info("Notifications enabled")
            
            # Interactive console for sending commands
            print("\nInteractive mode - commands:")
            print("  read - Read current value")
            print("  write <value> - Write value to characteristic (e.g., 'write hello')")
            print("  0xf - Send the special 0xF command the server looks for")
            print("  exit - Quit the program")
            
            while True:
                command = await asyncio.get_event_loop().run_in_executor(None, input, "\nCommand: ")
                
                if command == "read":
                    value = await client.read_gatt_char(MOISTURE_CHAR_UUID)
                    logger.info(f"Read value: {value}")
                    
                elif command.startswith("write "):
                    value = command[6:].encode()
                    await client.write_gatt_char(MOISTURE_CHAR_UUID, value)
                    logger.info(f"Wrote: {value}")
                    
                elif command == "0xf":
                    # Special command that triggers the server's response
                    await client.write_gatt_char(MOISTURE_CHAR_UUID, b"\x0f")
                    logger.info("Sent 0xF command")
                    
                elif command == "exit":
                    break
                
                else:
                    print("Unknown command")
                
        except Exception as e:
            logger.error(f"Error: {e}")
            
        finally:
            # Clean up
            try:
                await client.stop_notify(MOISTURE_CHAR_UUID)
                logger.info("Notifications disabled")
            except:
                pass

async def main():
    device = await find_ble_device()
    if device:
        await connect_to_device(device)
    else:
        logger.error("No suitable device found")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nApplication stopped by user")
