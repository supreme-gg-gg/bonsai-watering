//
//  BluetoothViewModel.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-03-17.
//

import Foundation
import CoreBluetooth
import Combine

class BLEPeripheralViewModel: ObservableObject {
	private var bluetoothManager: BLEPeripheralManager
	@Published var message: String = "No data received"
	@Published var waterLevel: WaterLevel?
	@Published var isConnected: Bool = false
	@Published var isAdvertising: Bool = false
	@Published var navigateToResult: Bool = false

	init() {
		self.bluetoothManager = BLEPeripheralManager()
		self.waterLevel = WaterLevel(percentage: 0)
	}

	func startAdvertising() {
		bluetoothManager.startAdvertising { [weak self] message in
			DispatchQueue.main.async {
				print("Received message from BLE: \(message)")
				self?.message = message

				// Parse the message based on the original design
				if message.starts(with: "Moisture: "),
				   let percentageString = message.components(separatedBy: ": ").last?.replacingOccurrences(of: "%", with: ""),
				   let percentage = Double(percentageString) {
					// Ensure percentage is within 0-100 range
					let clampedPercentage = min(max(percentage, 0), 100)
					self?.waterLevel = WaterLevel(percentage: clampedPercentage)
					self?.navigateToResult = true
				} else {
					// If parsing fails, set a default value and log a warning
					print("Warning: Could not parse a valid moisture percentage from: \(message)")
					self?.waterLevel = WaterLevel(percentage: 50) // Default value
					self?.navigateToResult = true
				}

				self?.isConnected = true
			}
		}

		isAdvertising = true
	}
	
	func disconnect() {
		bluetoothManager.stopAdvertising()
		message = "No data received"
		waterLevel = WaterLevel(percentage: 0)
		isConnected = false
		isAdvertising = false
		navigateToResult = false
	}
}

class BLECentralViewModel: ObservableObject {

	// MARK: - Properties
	private var bleManager: BLECentralManager
	private var discoveredPeripherals: [CBPeripheral] = [] // Store actual peripheral objects

	// --- Published Properties for UI Updates ---
	@Published var message: String = "Initializing..."
	@Published var waterLevel: WaterLevel? = WaterLevel(percentage: 0) // Default initial state
	@Published var isConnected: Bool = false
	@Published var isConnecting: Bool = false // Added state for connection process
	@Published var isScanning: Bool = false
	@Published var navigateToResult: Bool = false
	@Published var discoveredDevicesDisplay: [String] = [] // User-friendly list for Picker/List
	@Published var canScan: Bool = false // Controlled by BLE state
	@Published var connectionError: String? = nil

	// MARK: - Initialization
	init(bleManager: BLECentralManager = BLECentralManager()) {
		self.bleManager = bleManager
		self.bleManager.delegate = self // Set the ViewModel as the delegate
		// Initial state check
		updateCanScan(for: bleManager.currentBluetoothState)
		message = bleManager.currentBluetoothState == .poweredOn ? "Ready to scan" : "Bluetooth is \(bleManager.currentBluetoothState)"
		print("BLECentralViewModel initialized.")
	}

	// MARK: - UI Actions
	func startScanning() {
		guard !isScanning && canScan else {
			print("ViewModel: Cannot start scan (Already scanning or Bluetooth off).")
			message = canScan ? "Scan already in progress." : "Bluetooth is off. Please turn it on."
			return
		}

		print("ViewModel: Starting scan...")
		isScanning = true
		discoveredDevicesDisplay = []
		discoveredPeripherals = []
		connectionError = nil
		message = "Scanning for devices..."

		bleManager.startScan(timeout: 10.0) // Manager handles the actual scan logic
	}

	func stopScanning() {
		guard isScanning else { return }
		print("ViewModel: Stopping scan...")
		bleManager.stopScan()
		isScanning = false
		message = "Scan stopped."
		// Discovered devices list updated via delegate `bleManagerDidDiscoverPeripherals`
	}


	func connectToPeripheral(at index: Int) {
		guard index >= 0 && index < discoveredPeripherals.count else {
			print("ViewModel: Invalid peripheral index: \(index)")
			message = "Error: Invalid device selection."
			return
		}

		guard !isConnected && !isConnecting else {
			print("ViewModel: Already connected or connection in progress.")
			message = "Connection already in progress or established."
			return
		}

		let peripheral = discoveredPeripherals[index]
		let deviceName = peripheral.name ?? "Unknown Device (\(String(peripheral.identifier.uuidString.prefix(8)))"

		print("ViewModel: Attempting to connect to \(deviceName)...")
		message = "Connecting to \(deviceName)..."
		connectionError = nil
		isConnecting = true // Indicate connection attempt start

		bleManager.connect(to: peripheral) // Manager handles connection and calls delegate back
	}

	func disconnect() {
		guard isConnected || isConnecting else {
			print("ViewModel: Not connected or connecting.")
			return
		}
		print("ViewModel: Disconnecting...")
		message = "Disconnecting..."
		bleManager.disconnect() // Manager handles disconnection and calls delegate back

		// We could reset state here, but it's better to wait for the delegate callback
		// for didDisconnect to ensure the BLE stack is clean.
	}

	func refreshMoistureValue() {
		guard isConnected else {
			print("ViewModel: Cannot refresh value, not connected.")
			message = "Not connected. Cannot read data."
			return
		}

		print("ViewModel: Requesting moisture value refresh...")
		message = "Reading moisture value..."
		bleManager.readMoistureValue() // Manager handles read and calls delegate back
	}

	// MARK: - Private Helpers
	private func updateCanScan(for bleState: CBManagerState) {
		canScan = (bleState == .poweredOn)
	}

	private func mapPeripheralsToDisplay(_ peripherals: [CBPeripheral]) {
		let targetDeviceNameLower = bleManager.serverName.lowercased()
		
		// Sort peripherals so target devices come first
		let sortedPeripherals = peripherals.sorted { p1, p2 in
			let name1 = p1.name?.lowercased() ?? ""
			let name2 = p2.name?.lowercased() ?? ""
			let isTarget1 = name1.contains(targetDeviceNameLower)
			let isTarget2 = name2.contains(targetDeviceNameLower)
			return isTarget1 && !isTarget2
		}
		
		discoveredPeripherals = sortedPeripherals
		discoveredDevicesDisplay = sortedPeripherals.map { peripheral in
			let name = peripheral.name ?? "Unknown Device"
			let deviceId = peripheral.identifier.uuidString.prefix(8)
			let displayName = "\(name) (\(deviceId)...)"
			
			let isTargetDevice = name.lowercased().contains(targetDeviceNameLower)
			return isTargetDevice ? "★ \(displayName)" : displayName
		}
	}

	private func parseMoistureData(_ data: Data?) {
		 guard let data = data else {
			 print("ViewModel: Failed to read moisture value (data was nil).")
			 message = "Failed to read moisture value."
			 // Decide if nil data means error or just temporary issue
			 // self.waterLevel = nil // Optionally clear level on error
			 return
		 }

		 var parsed = false
		 if let valueString = String(data: data, encoding: .utf8) {
			 print("ViewModel: Received moisture value as String: \(valueString)")
			 if let percentage = Int(valueString.trimmingCharacters(in: .whitespacesAndNewlines)) {
				 let clampedPercentage = min(max(percentage, 0), 100)
				 self.waterLevel = WaterLevel(percentage: Double(clampedPercentage))
				 self.message = "Moisture: \(clampedPercentage)%"
				 self.navigateToResult = true // Trigger navigation on successful read
				 parsed = true
			 } else {
				 print("ViewModel: Warning: Could not parse integer from string: \(valueString)")
				 self.message = "Received: \(valueString) (invalid format)"
				 self.waterLevel = nil // Indicate invalid data
			 }
		 }

		// Fallback to binary if not UTF8 or parsing failed
		 if !parsed, let firstByte = data.first {
			  print("ViewModel: Received non-UTF8 data or parse failed, using first byte.")
			  let percentage = Int(firstByte)
			  let clampedPercentage = min(max(percentage, 0), 100)
			  self.waterLevel = WaterLevel(percentage: Double(clampedPercentage))
			  self.message = "Moisture: \(clampedPercentage)% (binary)"
			  self.navigateToResult = true // Trigger navigation
			  parsed = true
		  }

		 if !parsed {
			 print("ViewModel: Received empty or unparseable data.")
			 self.message = "Received unreadable data."
			 self.waterLevel = nil
		 }
	}
}

// MARK: - BLECentralManagerDelegate Conformance
extension BLECentralViewModel: BLECentralManagerDelegate {

	func bleManagerDidUpdateState(_ state: CBManagerState) {
		DispatchQueue.main.async {
			self.updateCanScan(for: state)
			if !self.canScan && (self.isConnected || self.isConnecting) {
				// If BT turns off while connected/connecting, reset state
				self.isConnected = false
				self.isConnecting = false
				self.message = "Bluetooth turned off."
				self.connectionError = "Bluetooth was turned off or became unavailable."
				self.navigateToResult = false
				self.waterLevel = WaterLevel(percentage: 0) // Reset
			} else if self.canScan {
				self.message = self.isScanning ? "Scanning..." : "Ready to scan"
			} else {
				 self.message = "Bluetooth is \(state)"
			}
			 print("ViewModel: Bluetooth state updated to \(state). CanScan: \(self.canScan)")
		}
	}

	func bleManagerDidDiscoverPeripherals(_ peripherals: [CBPeripheral]) {
		DispatchQueue.main.async {
			 print("ViewModel: Delegate received \(peripherals.count) discovered peripherals.")
			 self.mapPeripheralsToDisplay(peripherals)
			 self.isScanning = self.bleManager.isScanning // Sync scanning state just in case

			if !self.isScanning { // Only update message if scan finished
				if peripherals.isEmpty {
					  self.message = "No Bluetooth devices found."
				} else {
					// Check if our known device was among them
					let foundTargetDevice = peripherals.contains { peripheral in
						 guard let name = peripheral.name else { return false }
						 return name.lowercased().contains(self.bleManager.serverName.lowercased())
					 }

					 if foundTargetDevice {
						 self.message = "Found \(self.bleManager.serverName)! Select to connect."
					 } else {
						 self.message = "Found \(peripherals.count) device(s). Select one to connect."
					 }
				}
			}
		}
	}

	func bleManagerDidConnect(to peripheral: CBPeripheral) {
		DispatchQueue.main.async {
			 print("ViewModel: Delegate received successful connection to \(peripheral.name ?? "Unknown"). Waiting for services...")
			 self.isConnected = false // Still false until services are ready
			 self.isConnecting = true // Still technically connecting until ready
			 self.message = "Connected to \(peripheral.name ?? "Device"). Discovering services..."
			 self.connectionError = nil
		}
	}

	func bleManagerIsReadyToRead(from peripheral: CBPeripheral) {
		DispatchQueue.main.async {
			print("ViewModel: Delegate received ready signal from \(peripheral.name ?? "Unknown").")
			self.isConnected = true // NOW fully connected and ready
			self.isConnecting = false
			self.message = "Device ready. Reading initial value..."
			// Automatically read the value once ready
			self.refreshMoistureValue()
		}
	}

	func bleManager(didFailToConnect peripheral: CBPeripheral, error: Error?) {
		DispatchQueue.main.async {
			let name = peripheral.name ?? "Device"
			let errorDesc = error?.localizedDescription ?? "Unknown error"
			print("ViewModel: Delegate received connection failure for \(name). Error: \(errorDesc)")
			self.isConnected = false
			self.isConnecting = false
			self.message = "Failed to connect to \(name)."
			self.connectionError = errorDesc
		}
	}

	func bleManager(didDisconnect peripheral: CBPeripheral, error: Error?) {
		DispatchQueue.main.async {
			let name = peripheral.name ?? "Device"
			print("ViewModel: Delegate received disconnection from \(name). Error: \(error?.localizedDescription ?? "None")")
			self.isConnected = false
			self.isConnecting = false // Ensure connecting flag is also reset
			self.message = "Disconnected from \(name)."
			self.waterLevel = WaterLevel(percentage: 0) // Reset value
			self.navigateToResult = false // Ensure navigation resets
			if let error = error {
				self.connectionError = "Disconnected with error: \(error.localizedDescription)"
			} else {
				self.connectionError = nil // Clear error on clean disconnect
			}
			// Optionally clear device list or keep for reconnection attempt
			 // self.discoveredDevicesDisplay = []
			 // self.discoveredPeripherals = []
		}
	}

	func bleManager(didReceiveData data: Data?, for characteristicUUID: CBUUID, error: Error?) {
		DispatchQueue.main.async {
			 guard characteristicUUID == self.bleManager.moistureCharUUID else {
				 print("ViewModel: Received data for unexpected characteristic \(characteristicUUID). Ignoring.")
				 return // Ignore data from other characteristics for now
			 }

			 if let error = error {
				 print("ViewModel: Delegate received error reading moisture value: \(error.localizedDescription)")
				 self.message = "Error reading value: \(error.localizedDescription)"
				  self.waterLevel = nil
				 return
			 }

			 print("ViewModel: Delegate received moisture data.")
			 self.parseMoistureData(data) // Use the existing parsing logic
		}
	}
}
