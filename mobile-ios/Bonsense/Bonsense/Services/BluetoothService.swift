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
	
	// Service and characteristic UUIDs
	private let serviceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")
	private let characteristicUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef1")
	
	override init() {
		super.init()
		// Use a dedicated queue for Bluetooth operations
		let queue = DispatchQueue(label: "com.bonsai.bluetooth", qos: .userInitiated)
		peripheralManager = CBPeripheralManager(delegate: self, queue: queue)
	}
	
	func startAdvertising(messageHandler: @escaping (String) -> Void) {
		messageUpdateHandler = messageHandler
		
		// Check current state and act accordingly
		if peripheralManager.state == .poweredOn {
			print("Bluetooth is ready, setting up service...")
			setupService()
		} else {
			print("Bluetooth not ready (state: \(peripheralManager.state.rawValue)), waiting for state update...")
		}
	}
	
	func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
		print("Bluetooth state changed to: \(peripheral.state.rawValue)")
		
		switch peripheral.state {
		case .poweredOn:
			print("Bluetooth is powered on, setting up service...")
			setupService()
		case .poweredOff:
			print("❌ Bluetooth is powered off")
		case .unauthorized:
			print("❌ Bluetooth is unauthorized")
		case .unsupported:
			print("❌ Bluetooth is unsupported")
		case .resetting:
			print("⚠️ Bluetooth is resetting")
		case .unknown:
			print("⚠️ Bluetooth state unknown")
		@unknown default:
			print("⚠️ Unknown Bluetooth state")
		}
	}
	
	private func setupService() {
		// Remove any existing services
		if peripheralManager.isAdvertising {
			peripheralManager.stopAdvertising()
			print("Stopped previous advertising")
		}
		
		// Create the characteristic
		moistureCharacteristic = CBMutableCharacteristic(
			type: characteristicUUID,
			properties: [.read, .write, .notify],
			value: nil,
			permissions: [.readable, .writeable]
		)
		
		// Create the service
		let sensorService = CBMutableService(type: serviceUUID, primary: true)
		sensorService.characteristics = [moistureCharacteristic]
		
		print("✅ Adding service: \(serviceUUID.uuidString)")
		peripheralManager.add(sensorService)
	}
	
	func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
		if let error = error {
			print("Failed to add service: \(error.localizedDescription)")
			return
		}
		
		print("Service added successfully: \(service.uuid.uuidString)")
		
		// Start advertising with a delay to ensure service registration
		DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
			let advertisementData: [String: Any] = [
				CBAdvertisementDataLocalNameKey: "BonsaiPeripheral",
				CBAdvertisementDataServiceUUIDsKey: [service.uuid]
			]
			
			self.peripheralManager.startAdvertising(advertisementData)
			print("Started advertising with data: \(advertisementData)")
		}
	}
	
	func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
		if let error = error {
			print("Failed to start advertising: \(error.localizedDescription)")
		} else {
			print("✅ Successfully started advertising")
		}
	}
	
	func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
		print("Received read request for characteristic: \(request.characteristic.uuid.uuidString)")
		
		if request.characteristic.uuid == characteristicUUID {
			// Create a default value if none exists
			if moistureCharacteristic.value == nil {
				let defaultValue = "No moisture data yet".data(using: .utf8)!
				moistureCharacteristic.value = defaultValue
			}
			
			// Update the value
			request.value = moistureCharacteristic.value
			peripheral.respond(to: request, withResult: .success)
			print("Responded to read request with value: \(String(describing: moistureCharacteristic.value))")
		} else {
			peripheral.respond(to: request, withResult: .attributeNotFound)
			print("⚠️ Read request for unknown characteristic")
		}
	}
	
	func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
		print("Received \(requests.count) write requests")
		
		for request in requests {
			if request.characteristic.uuid == characteristicUUID {
				if let value = request.value, let message = String(data: value, encoding: .utf8) {
					print("Received write with value: \(message)")
					
					// Store the value
					moistureCharacteristic.value = value
					
					// Notify the UI
					DispatchQueue.main.async {
						self.messageUpdateHandler?(message)
					}
					
					// Also send a notification to subscribers if there are any
//                    let subscribers = peripheral.subscribedCentrals ?? []
//                    if !subscribers.isEmpty {
//                        let didNotify = peripheral.updateValue(value, for: moistureCharacteristic, onSubscribedCentrals: nil)
//                        print("Notified subscribers: \(didNotify ? "success" : "queued")")
//                    }
					
					peripheral.respond(to: request, withResult: .success)
				} else {
					print("⚠️ Invalid write value or encoding")
					peripheral.respond(to: request, withResult: .invalidAttributeValueLength)
				}
			} else {
				print("⚠️ Write request for unknown characteristic")
				peripheral.respond(to: request, withResult: .attributeNotFound)
			}
		}
	}
	
	func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
		print("Central \(central.identifier) subscribed to notifications for \(characteristic.uuid.uuidString)")
		
		// Send initial value
		if characteristic.uuid == characteristicUUID {
			let initialValue = "Initial moisture data".data(using: .utf8)!
			peripheral.updateValue(initialValue, for: moistureCharacteristic, onSubscribedCentrals: [central])
		}
	}
	
	func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
		print("Central \(central.identifier) unsubscribed from \(characteristic.uuid.uuidString)")
	}
}
