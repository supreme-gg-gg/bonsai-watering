//
//  BluetoothService.swift
//  testing-bluetooth
//
//  Created by Jet Chiang on 2025-03-16.
//

import CoreBluetooth

class BLEPeripheralManager: NSObject, CBPeripheralManagerDelegate {
	private var peripheralManager: CBPeripheralManager!
	private var moistureCharacteristic: CBMutableCharacteristic!
	private let serviceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef3")
	private let characteristicUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef4")
	private var messageUpdateHandler: ((String) -> Void)?
	private var serviceSetupCompleted = false

	override init() {
		super.init()
		let queue = DispatchQueue(label: "com.bonsai.bluetooth", qos: .userInitiated)
		peripheralManager = CBPeripheralManager(delegate: self, queue: queue)
	}

	func startAdvertising(messageHandler: @escaping (String) -> Void) {
		self.messageUpdateHandler = messageHandler
		if peripheralManager.state == .poweredOn {
			setupServiceIfNeeded()
		}
	}

	func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
		if peripheral.state == .poweredOn {
			setupServiceIfNeeded()
		}
	}

	private func setupServiceIfNeeded() {
		if !serviceSetupCompleted {
			setupService()
			serviceSetupCompleted = true
		}
	}

	private func setupService() {
		print("Setting up Service and Char")
		print("Service UUID: \(serviceUUID.uuidString)")
		print("Char UUID: \(characteristicUUID.uuidString)")
		moistureCharacteristic = CBMutableCharacteristic(
			type: characteristicUUID,
			properties: [.read, .write, .notify],
			value: nil,
			permissions: [.readable, .writeable]
		)
		let sensorService = CBMutableService(type: serviceUUID, primary: true)
		sensorService.characteristics = [moistureCharacteristic]
		peripheralManager.add(sensorService)
	}

	func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
		if error == nil {
			let advertisementData: [String: Any] = [
				CBAdvertisementDataLocalNameKey: "BonsaiPeripheral_Test",
				CBAdvertisementDataServiceUUIDsKey: [service.uuid]
			]
			peripheralManager.startAdvertising(advertisementData)
		}
	}

	func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
		if request.characteristic.uuid == characteristicUUID {
			request.value = moistureCharacteristic.value ?? "No data".data(using: .utf8)
			peripheral.respond(to: request, withResult: .success)
		} else {
			peripheral.respond(to: request, withResult: .attributeNotFound)
		}
	}

	func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
		for request in requests {
			if request.characteristic.uuid == characteristicUUID, let value = request.value, let message = String(data: value, encoding: .utf8) {
				moistureCharacteristic.value = value
				peripheral.updateValue(value, for: moistureCharacteristic, onSubscribedCentrals: nil)
				peripheral.respond(to: request, withResult: .success)
				DispatchQueue.main.async {
					self.messageUpdateHandler?(message)
				}
			} else {
				peripheral.respond(to: request, withResult: .attributeNotFound)
			}
		}
	}

	func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
		if characteristic.uuid == characteristicUUID {
			peripheral.updateValue("Initial data".data(using: .utf8)!, for: moistureCharacteristic, onSubscribedCentrals: nil)
		}
	}
}
