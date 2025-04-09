# The missing handbook for BLE development

The first time I tried to setup BLE on ESP32 and connect it to a React Native app, I failed miserably aftering wasting over 24 hours in a hackathon. Two nights without sleep just to see nothing working during the demo.

The second time saw no better consequences. Raspberry Pi and Swift taught me an equally bitter lesson. Another weekend was sacrificed to the gods of BLE, with nothing in return.

The divine intervention came right at my hour of despair when I was about to give up my second attempt and switch to the good old WiFi. I eventually managed to setup both a central and a peripheral on the Pi and connected them to my iOS app.

I hope if you are a lost soul like I was, this guide will help you to get started with BLE development. May it be a torch in the dark forest of BLE development.

## Background

Make sure you know how BLE works before you start. Otherwise be prepared to get cooked.

## Libraries

The biggest difficulty of BLE development is the lack of good documentation, clear examples, and straightforward choices for libraries. There are numerous libraries available but they are either outdated, poorly documented, or not working for god-knows-what reason.

1. `bluepy` - A Python library for interfacing with BLE devices. It is a good choice for Raspberry Pi and other Linux-based systems. However, it only supports connecting to peripherals and not acting as a central device (it has a `Peripheral` class which sounds misleading). If you see `import bluetooth` in sample code, it is likely using `bluepy`.

2. `bleak` - This works every time I tried and I would recommend this for cross-platform compatibility. It allows you to connect to BLE devices from any platform (Windows, Linux, macOS) and is actively maintained. It has a very simple API documentation.

3. `bless` - This is the only simple Python library I found that allows you to act as a BLE peripheral. Most other ones are just central devices. This is often used in combination with `bleak`.

4. `bluez` - This is the official Linux Bluetooth stack and is used by many libraries. It is a low-level library and requires a lot of boilerplate code to get started. It is not recommended for beginners. You can always find ways to work with its Python bindings.

5. `CoreBluetooth` - This is the official Apple library for BLE development. It is only available on macOS and iOS. It isn't really low-levle but it requires a whole bunch of boilerplate code to get started. Its API is extremely unintuitive and often you just end up copying and pasting code from StackOverflow / random online blogs. However, it is the only way to work with Swift apps.

6. `Noble` - This is a Node.js library for BLE development. It is a good choice for Raspberry Pi and other Linux-based systems. It is actively maintained and has a simple API. However, it is not as widely used as `bluepy` or `bleak`.

7. `noble` - Haven't used this one but it is a quite popular Node.js library for BLE central (not peripheral). It works on pretty much any platform as long as you have Node.js installed. Do note that JS packages simply won't work with your Python code for other raspberry pi functions such as GPIO. You will need to use `noble` in a separate process and communicate with it using sockets or some other IPC method.

8. `bleno` - Often used in combination with `noble`, this is a Node.js library for BLE peripheral development. It is a good choice for Raspberry Pi and other Linux-based systems. It is actively maintained and has a simple API.
