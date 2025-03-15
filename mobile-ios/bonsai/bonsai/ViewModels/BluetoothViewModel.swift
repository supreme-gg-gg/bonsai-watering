//
//  BluetoothViewModel.swift
//  bonsai
//
//  Created by Jet Chiang on 2025-03-15.
//

import Foundation
import CoreBluetooth
import SwiftData

class BluetoothViewModel: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
	@Published var discoveredDevices: [CBPeripheral] = []
	@Published var pairedDevice: CBPeripheral?
	@Published var receivedData: String = "" // Stores incoming data
	@Published var isScanning = false
	@Published var isConnected = false
	
	private var centralManager: CBCentralManager!
	private var modelContext: ModelContext?
	private var txCharacteristic: CBCharacteristic?
	private var rxCharacteristic: CBCharacteristic?

	override init() {
		super.init()
		self.centralManager = CBCentralManager(delegate: self, queue: nil)
	}
	
	// Inject SwiftData ModelContext
	func setContext(_ context: ModelContext) {
		self.modelContext = context
		fetchPairedDevice()
	}

	// MARK: - Bluetooth Scanning
	func startScanning() {
		discoveredDevices.removeAll()
		isScanning = true
		centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])

		DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
			self.stopScanning()
		}
	}
	
	func stopScanning() {
		isScanning = false
		centralManager.stopScan()
	}

	// MARK: - Bluetooth Connection
	func connectToDevice(_ device: CBPeripheral) {
		pairedDevice = device
		device.delegate = self
		centralManager.connect(device, options: nil)

		// Save to SwiftData
		if let context = modelContext {
			let storedDevice = BluetoothDevice(deviceID: device.identifier.uuidString, name: device.name ?? "Unknown")
			context.insert(storedDevice)
			try? context.save()
		}
	}

	func disconnectFromDevice() {
		if let device = pairedDevice {
			centralManager.cancelPeripheralConnection(device)
			pairedDevice = nil
			isConnected = false
		}

		// Remove from SwiftData
		if let context = modelContext, let storedDevice = fetchStoredDevice() {
			context.delete(storedDevice)
			try? context.save()
		}
	}
	
	// MARK: - SwiftData Management
	func fetchPairedDevice() {
		if let context = modelContext {
			let fetchDescriptor = FetchDescriptor<BluetoothDevice>()
			if let storedDevice = try? context.fetch(fetchDescriptor).first {
				let matchingPeripheral = discoveredDevices.first { $0.identifier.uuidString == storedDevice.deviceID }
				pairedDevice = matchingPeripheral
			}
		}
	}

	private func fetchStoredDevice() -> BluetoothDevice? {
		guard let context = modelContext else { return nil }
		let fetchDescriptor = FetchDescriptor<BluetoothDevice>()
		return try? context.fetch(fetchDescriptor).first
	}

	// MARK: - CBCentralManagerDelegate
	func centralManagerDidUpdateState(_ central: CBCentralManager) {
		if central.state == .poweredOn {
			fetchPairedDevice()
		}
	}
	
	func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
		if !discoveredDevices.contains(peripheral) {
			discoveredDevices.append(peripheral)
		}
	}
	
	func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
		print("Connected to \(peripheral.name ?? "Unknown Device")")
		pairedDevice = peripheral
		isConnected = true
		peripheral.delegate = self
		peripheral.discoverServices(nil)
	}
	
	func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
		print("Disconnected from \(peripheral.name ?? "Unknown Device")")
		pairedDevice = nil
		isConnected = false
	}
	
	// MARK: - CBPeripheralDelegate
	func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
		guard let services = peripheral.services else { return }
		for service in services {
			peripheral.discoverCharacteristics(nil, for: service)
		}
	}

	func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
		guard let characteristics = service.characteristics else { return }
		for characteristic in characteristics {
			if characteristic.uuid == CBUUIDs.BLE_Characteristic_uuid_Rx {
				rxCharacteristic = characteristic
				peripheral.setNotifyValue(true, for: rxCharacteristic!)
			} else if characteristic.uuid == CBUUIDs.BLE_Characteristic_uuid_Tx {
				txCharacteristic = characteristic
			}
		}
	}

	func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
		guard let data = characteristic.value,
			  let receivedString = String(data: data, encoding: .utf8) else { return }
		DispatchQueue.main.async {
			self.receivedData = receivedString
		}
	}
}
