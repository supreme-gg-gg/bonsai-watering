import sys
import logging
import asyncio
import threading
import json
import time
from collections import deque
from typing import Any, Union
import RPi.GPIO as GPIO

from bless import (
    BlessServer,
    BlessGATTCharacteristic,
    GATTCharacteristicProperties,
    GATTAttributePermissions,
)

# GPIO setup
GPIO.setmode(GPIO.BCM)
MOISTURE_SENSOR_PIN = 21  # Adjust this to your actual GPIO pin
GPIO.setup(MOISTURE_SENSOR_PIN, GPIO.IN)

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# Some systems require different synchronization methods.
trigger: Union[asyncio.Event, threading.Event]
if sys.platform in ["darwin", "win32"]:
    trigger = threading.Event()
else:
    trigger = asyncio.Event()

# Store last 24 moisture readings (FIFO queue)
moisture_data = deque(maxlen=24)

def read_moisture_level():
    """Reads GPIO input and returns the moisture level (0 or 1) with a timestamp."""
    value = GPIO.input(MOISTURE_SENSOR_PIN)
    timestamp = time.time()  # Unix timestamp
    return {"moisture": value, "timestamp": timestamp}

def update_moisture_readings():
    """Reads and stores the latest moisture reading every 10 seconds."""
    while True:
        moisture_data.append(read_moisture_level())
        time.sleep(10)  # Adjust interval as needed

async def read_request(characteristic: BlessGATTCharacteristic, **kwargs) -> bytearray:
    """Handles read requests from the BLE client (Swift app)."""
    global moisture_data
    data = list(moisture_data)  # Convert deque to list
    json_data = json.dumps(data).encode('utf-8')
    logger.debug(f"Sending Moisture Data: {json_data}")
    return json_data

async def run(loop):
    trigger.clear()

    # Instantiate the BLE Server
    server = BlessServer(name="MoistureSensor", loop=loop)
    server.read_request_func = read_request

    # Define a Service UUID
    service_uuid = "A07498CA-AD5B-474E-940D-16F1FBE7E8CD"
    await server.add_new_service(service_uuid)

    # Define a Characteristic UUID
    char_uuid = "51FF12BB-3ED8-46E5-B4F9-D64E2FEC021B"
    char_props = (
        GATTCharacteristicProperties.read |
        GATTCharacteristicProperties.notify
    )
    permissions = GATTAttributePermissions.readable

    await server.add_new_characteristic(service_uuid, char_uuid, char_props, None, permissions)

    # Start the background moisture sensor thread
    sensor_thread = threading.Thread(target=update_moisture_readings, daemon=True)
    sensor_thread.start()

    # Start BLE server
    await server.start()
    logger.info("BLE server running. Waiting for connections...")

    try:
        if trigger.__module__ == "threading":
            trigger.wait()
        else:
            await trigger.wait()
    except KeyboardInterrupt:
        pass

    await server.stop()
    GPIO.cleanup()

# Start event loop
loop = asyncio.get_event_loop()
loop.run_until_complete(run(loop))
