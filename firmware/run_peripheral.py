import sys
import logging
import asyncio
import threading
import time
import spidev
import numpy as np

from typing import Any, Union

from bless import (  # type: ignore
    BlessServer,
    BlessGATTCharacteristic,
    GATTCharacteristicProperties,
    GATTAttributePermissions,
)

# Import the CalibratedMoistureSensor class
from calibrated_sensor import CalibratedMoistureSensor

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(name=__name__)

# Define UUIDs for our service and characteristic
MOISTURE_SERVICE_UUID = "12345678-1234-5678-1234-56789abcdef0"
MOISTURE_CHAR_UUID = "12345678-1234-5678-1234-56789abcdef1"
SERVER_NAME = "BonsaiPeripheral"

# NOTE: Some systems require different synchronization methods.
trigger: Union[asyncio.Event, threading.Event]
if sys.platform in ["darwin", "win32"]:
    trigger = threading.Event()
else:
    trigger = asyncio.Event()

# Global sensor instance
moisture_sensor = None

def read_request(characteristic: BlessGATTCharacteristic, **kwargs) -> bytearray:
    """
    Handle read requests from clients
    The client must send a read request every time it wants to read the moisture value.
    NOTE: Alternatively, we repeatedly read automatically, set the characterstic.value
    every few seconds, and notify the client by server.update_value(my_service_uuid, my_char_uuid)
    """
    logger.debug(f"Reading {characteristic.value}")
    
    # If this is a read from the moisture characteristic, get fresh data
    if characteristic.uuid == MOISTURE_CHAR_UUID:
        try:
            # Get current moisture reading
            if moisture_sensor:
                moisture_value = moisture_sensor.read_calibrated()
                # Convert float to string and then to bytearray
                characteristic.value = bytearray(f"{moisture_value:.2f}".encode())
                logger.info(f"Sending moisture value: {moisture_value:.2f}%")
        except Exception as e:
            logger.error(f"Error reading moisture sensor: {e}")
    
    return characteristic.value


def write_request(characteristic: BlessGATTCharacteristic, value: Any, **kwargs):
    """
    Handle write requests from clients
    NOTE: Obviously the client cannot write to the sensor lol
    """
    characteristic.value = value
    logger.debug(f"Char value set to {characteristic.value}")
    
    # Special command handling
    if characteristic.value == b"\x0f":
        logger.debug("Received special command (0x0F)")
        trigger.set()


async def update_moisture_readings(server: BlessServer,
                                   service_uuid: str,
                                   characteristic: BlessGATTCharacteristic,
                                   char_uuid: str,
                                   interval: int =5.0):
    """
    Periodically update moisture readings and notify clients
    """
    try:
        while True:
            if moisture_sensor:
                try:
                    # Read moisture value
                    moisture_value = moisture_sensor.read_calibrated()
                    
                    # Format as string with 2 decimal places
                    moisture_str = f"{moisture_value:.2f}"
                    logger.info(f"Current moisture: {moisture_str}%")
                    
                    # Update characteristic value
                    characteristic.value = bytearray(moisture_str.encode())
                    server.update_value(service_uuid, char_uuid)
                    
                except Exception as e:
                    logger.error(f"Error updating moisture value: {e}")
            
            # Wait before next update
            await asyncio.sleep(interval)
    except asyncio.CancelledError:
        logger.info("Moisture update task cancelled")


async def run(loop):
    global moisture_sensor
    
    # Initialize the moisture sensor
    try:
        moisture_sensor = CalibratedMoistureSensor(channel=0)
        logger.info("Moisture sensor initialized")
    except Exception as e:
        logger.error(f"Failed to initialize moisture sensor: {e}")
        moisture_sensor = None
    
    # Clear any previous triggers
    trigger.clear()
    
    # Instantiate the BLE server
    server = BlessServer(name=SERVER_NAME, loop=loop)
    server.read_request_func = read_request
    server.write_request_func = write_request

    # Add Moisture Service
    await server.add_new_service(MOISTURE_SERVICE_UUID)

    # Add Moisture Characteristic
    char_flags = (
        GATTCharacteristicProperties.read
        | GATTCharacteristicProperties.write
        | GATTCharacteristicProperties.notify
        | GATTCharacteristicProperties.indicate
    )
    permissions = GATTAttributePermissions.readable | GATTAttributePermissions.writeable
    
    await server.add_new_characteristic(
        MOISTURE_SERVICE_UUID,
        MOISTURE_CHAR_UUID,
        char_flags,
        bytearray("0.00".encode()),  # Initial value
        permissions
    )

    logger.debug(f"Created characteristic: {server.get_characteristic(MOISTURE_CHAR_UUID)}")
    
    # Start the server
    await server.start()
    logger.info(f"BLE Server '{SERVER_NAME}' started and advertising")
    logger.info(f"Service UUID: {MOISTURE_SERVICE_UUID}")
    logger.info(f"Characteristic UUID: {MOISTURE_CHAR_UUID}")
    
    try:
        # Run until triggered to stop
        if trigger.__module__ == "threading":
            # Wait for trigger in a non-blocking way
            while not trigger.is_set():
                await asyncio.sleep(1)
        else:
            await trigger.wait()
        
        logger.info("Shutdown trigger received")
        
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received")
    finally:
        if moisture_sensor:
            try:
                moisture_sensor.close()
                logger.info("Moisture sensor closed")
            except:
                pass
        
        await server.stop()
        logger.info("BLE server stopped")


if __name__ == "__main__":
    loop = asyncio.get_event_loop()
    try:
        loop.run_until_complete(run(loop))
    except KeyboardInterrupt:
        logger.info("Program stopped by user")
    finally:
        loop.close()
