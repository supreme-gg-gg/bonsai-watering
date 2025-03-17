import asyncio
from bleak import BleakClient, BleakScanner

SERVICE_UUID = "1234"
CHARACTERISTIC_UUID = "5678"

async def send_message():
    print("🔍 Scanning for BLE devices...")
    devices = await BleakScanner.discover()
    
    target_device = None
    for device in devices:
        print(f"Found: {device.name} - {device.address}")
        if device.name == "iPhone":  # Change this to your iPhone's name
            target_device = device
            break

    if not target_device:
        print("❌ iPhone not found!")
        return

    async with BleakClient(target_device.address) as client:
        print(f"✅ Connected to {target_device.name}")

        message = "Hello from Raspberry Pi!"
        await client.write_gatt_char(CHARACTERISTIC_UUID, message.encode())

        print(f"📨 Sent: {message}")

asyncio.run(send_message())
