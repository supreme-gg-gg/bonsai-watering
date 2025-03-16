//
//  BluetoothService.swift
//  testing-bluetooth
//
//  Created by Jet Chiang on 2025-03-16.
//

import Foundation
import CoreBluetooth

class BLEPeripheralManager: NSObject, CBPeripheralManagerDelegate {
	private var peripheralManager: CBPeripheralManager!
	private var moistureCharacteristic: CBMutableCharacteristic!
	private var messageUpdateHandler: ((String) -> Void)?

	override init() {
		super.init()
		peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
	}

	func startAdvertising(messageHandler: @escaping (String) -> Void) {
		messageUpdateHandler = messageHandler
		guard peripheralManager.state == .poweredOn else {
			print("Bluetooth not ready, waiting for state update...")
			return
		}
		setupService()
	}

	func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
		if peripheral.state == .poweredOn {
			setupService()
		} else {
			print("❌ Bluetooth not available")
		}
	}

	private func setupService() {
		let serviceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")
		let characteristicUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef1")

		moistureCharacteristic = CBMutableCharacteristic(
			type: characteristicUUID,
			properties: [.read, .write, .notify],
			value: nil,
			permissions: [.readable, .writeable]
		)

		let sensorService = CBMutableService(type: serviceUUID, primary: true)
		sensorService.characteristics = [moistureCharacteristic]

		print("✅ Adding service...")
		peripheralManager.add(sensorService) // Will trigger didAdd callback
	}

	func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
		if let error = error {
			print("Failed to add service: \(error.localizedDescription)")
			return
		}
		print("Service added successfully")

		DispatchQueue.main.asyncAfter(deadline: .now() + 1) { // Delay to ensure service is registered
			self.peripheralManager.startAdvertising([
				CBAdvertisementDataLocalNameKey: "BonsaiPeripheral",
				CBAdvertisementDataServiceUUIDsKey: [service.uuid]
			])
			print("Started advertising BLE service")
		}
	}

	func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
		for request in requests {
			if let value = request.value, let message = String(data: value, encoding: .utf8) {
				DispatchQueue.main.async {
					self.messageUpdateHandler?(message)
				}
				moistureCharacteristic.value = value
			}
			peripheral.respond(to: request, withResult: .success)
		}
	}
}
