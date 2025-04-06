//
//  BluetoothViewModel.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-03-17.
//

import Foundation
import CoreBluetooth

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
	private var discoveredPeripherals: [CBPeripheral] = [] // Keep track of actual CBPeripheral objects

	// --- Published Properties for UI Updates ---
	@Published var message: String = "Ready to connect"
	@Published var waterLevel: WaterLevel? = WaterLevel(percentage: 0) // Initialize
	@Published var isConnected: Bool = false
	@Published var isScanning: Bool = false
	@Published var navigateToResult: Bool = false // For programmatic navigation
	@Published var discoveredDevices: [String] = [] // User-friendly list of names/identifiers
	@Published var canScan: Bool = true // Added: To control scan button enable/disable based on BLE state (optional but good UX)
	@Published var connectionError: String? = nil // To display connection errors

	// MARK: - Initialization
	init(bleManager: BLECentralManager = BLECentralManager()) { // Allow injecting for testing
		self.bleManager = bleManager
		// Optional: Observe BLE state from manager if you add a publisher/delegate there
		// For now, we rely on function call results
		print("BLECentralViewModel initialized.")
	}

	// MARK: - Scanning
	func startScanning() {
		guard !isScanning else {
			print("ViewModel: Scan already in progress.")
			return
		}

		print("ViewModel: Starting scan...")
		isScanning = true
		discoveredDevices = []
		discoveredPeripherals = []
		connectionError = nil // Clear previous errors

		let knownDeviceNames = ["raspi", "BonsaiPeripheral", "bonsai", "raspberry"]

		// Then replace the scan completion handler:
		bleManager.requestScan(timeout: 10.0) { [weak self] peripherals in
			// This completion runs AFTER the scan finishes (timeout or stopped)
			DispatchQueue.main.async {
				guard let self = self else { return }

				print("ViewModel: Scan completed. Found \(peripherals.count) peripherals.")
				self.discoveredPeripherals = peripherals
				
				// Create display names with optional indicators for known devices
				self.discoveredDevices = peripherals.map { peripheral in
					let name = peripheral.name ?? "Unknown Device"
					let deviceId = peripheral.identifier.uuidString.prefix(8)
					
					// Check if this is one of our known devices
					let isKnownDevice = self.bleManager.serverNames.contains { knownName in
						name.lowercased().contains(knownName.lowercased())
					}
					
					// Add an indicator for known devices
					if isKnownDevice {
						return "★ \(name) (\(deviceId)...)"
					} else {
						return "\(name) (\(deviceId)...)"
					}
				}

				self.isScanning = false // Update scanning state

				if peripherals.isEmpty {
					self.message = "No Bluetooth devices found."
				} else {
					// Check if any of our known devices were found
					let foundKnownDevice = peripherals.contains { peripheral in
						guard let name = peripheral.name else { return false }
						return self.bleManager.serverNames.contains { knownName in
							name.lowercased().contains(knownName.lowercased())
						}
					}
					
					if foundKnownDevice {
						self.message = "Found bonsai device! Select to connect."
					} else {
						self.message = "Found \(peripherals.count) devices. Select one to connect."
					}
				}
			}
		}
	}

	// MARK: - Connection
	func connectToPeripheral(at index: Int) {
		guard index >= 0 && index < discoveredPeripherals.count else {
			print("ViewModel: Invalid peripheral index: \(index)")
			message = "Error: Invalid device selection."
			return
		}

		guard !isConnected else {
			print("ViewModel: Already connected or connection in progress.")
			// Optionally disconnect first if you want to switch devices
			return
		}

		let peripheral = discoveredPeripherals[index]
		let deviceName = peripheral.name ?? "Unknown Device"

		print("ViewModel: Attempting to connect to \(deviceName)...")
		message = "Connecting to \(deviceName)..."
		connectionError = nil

		bleManager.connect(to: peripheral) { [weak self] success, error in
			// This completion handler is called when connection attempt finishes
			DispatchQueue.main.async {
				guard let self = self else { return }

				if success {
					print("ViewModel: Successfully connected to \(deviceName).")
					self.isConnected = true
					self.message = "Connected to \(deviceName). Reading data..."

					// Connection succeeded, now try reading the initial value
					// Add a small delay to allow services/characteristics discovery to potentially complete
					// NOTE: A more robust solution involves the BLEManager signaling readiness via delegate/publisher.
					DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
					   self.readMoistureValue()
					}

				} else {
					print("ViewModel: Failed to connect to \(deviceName). Error: \(error?.localizedDescription ?? "Unknown error")")
					self.isConnected = false
					self.message = "Failed to connect to \(deviceName)."
					self.connectionError = error?.localizedDescription ?? "An unknown connection error occurred."
					// Consider clearing discovered devices or allowing retry
				}
			}
		}
	}

	// MARK: - Data Interaction
	func readMoistureValue() {
		guard isConnected else {
			print("ViewModel: Cannot read value, not connected.")
			message = "Not connected. Cannot read data."
			// Optionally attempt reconnect or guide user
			return
		}

		print("ViewModel: Requesting moisture value read...")
		message = "Reading moisture value..."

		bleManager.readMoistureValue { [weak self] data in
			DispatchQueue.main.async {
				guard let self = self else { return }
				guard let data = data else {
					print("ViewModel: Failed to read moisture value (data was nil).")
					self.message = "Failed to read moisture value."
					// Consider if this means disconnection
					// self.isConnected = false // Or maybe just show error? Depends on desired UX.
					return
				}

				// --- Parsing Logic (copied from your original, seems reasonable) ---
				if let valueString = String(data: data, encoding: .utf8) {
					print("ViewModel: Received moisture value as String: \(valueString)")
					if let percentage = Int(valueString.trimmingCharacters(in: .whitespacesAndNewlines)) {
						let clampedPercentage = min(max(percentage, 0), 100)
						self.waterLevel = WaterLevel(percentage: Double(clampedPercentage))
						self.message = "Moisture: \(clampedPercentage)%"
						self.navigateToResult = true // Trigger navigation on successful read
					} else {
						print("ViewModel: Warning: Could not parse integer from string: \(valueString)")
						self.message = "Received: \(valueString) (invalid format)"
						self.waterLevel = nil // Indicate invalid data
					}
				} else if let firstByte = data.first { // Fallback to binary if not UTF8
					 print("ViewModel: Received non-UTF8 data, using first byte.")
					 let percentage = Int(firstByte)
					 let clampedPercentage = min(max(percentage, 0), 100)
					 self.waterLevel = WaterLevel(percentage: Double(clampedPercentage))
					 self.message = "Moisture: \(clampedPercentage)% (binary)"
					 self.navigateToResult = true // Trigger navigation
				 } else {
					print("ViewModel: Received empty data.")
					self.message = "Received empty data."
					self.waterLevel = nil
				 }
				// --- End Parsing Logic ---
			}
		}
	}

	// MARK: - Refresh & Disconnect
	func refreshMoistureValue() {
		// Re-uses the readMoistureValue logic
		readMoistureValue()
	}

	func disconnect() {
		print("ViewModel: Disconnecting...")
		bleManager.disconnect()

		// Reset state immediately in the UI
		isConnected = false
		message = "Disconnected."
		waterLevel = WaterLevel(percentage: 0) // Reset to default or nil
		navigateToResult = false
		// Optionally clear discovered devices or keep them for reconnect
		// discoveredDevices = []
		// discoveredPeripherals = []
		connectionError = nil
	}
}
