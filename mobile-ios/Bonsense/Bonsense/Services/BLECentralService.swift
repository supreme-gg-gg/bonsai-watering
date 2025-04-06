//
//  BLECentralService.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-04-05.
//

import Foundation
import CoreBluetooth
class BLECentralManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {

	// MARK: - Properties

	private var centralManager: CBCentralManager!
	private var connectedPeripheral: CBPeripheral? // Renamed for clarity
	private var discoveredPeripherals: [CBPeripheral] = [] // To collect peripherals during scan

	// Service and characteristic UUIDs
	private let moistureServiceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")
	private let moistureCharUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef1")

	// Device name to search for
	let serverNames = ["raspi", "BonsaiPeripheral"]

	// State Tracking
	private var scanTimer: Timer?
	private var scanRequested = false
	private var isConnecting = false // Flag to avoid duplicate connection attempts

	// Completion Handlers
	private var discoveryCompletion: (([CBPeripheral]) -> Void)?
	private var connectionCompletion: ((Bool, Error?) -> Void)? // Optional: For reporting connection success/failure
	private var readCompletion: ((Data?) -> Void)?

	// MARK: - Initialization

	override init() {
		super.init()
		// Initialize CBCentralManager on the main queue
		centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
		print("BLECentralManager initialized.")
	}

	func getBluetoothState() -> CBManagerState {
        return centralManager.state
    }

	// MARK: - Public Methods

	/// Requests a scan for peripherals advertising the specified service UUID.
	/// Calls the completion handler after a timeout or when the target device is found.
	/// - Parameters:
	///   - timeout: Duration in seconds to scan before stopping. Defaults to 10 seconds.
	///   - completion: Handler called with the list of discovered peripherals matching the name.
	func requestScan(timeout: TimeInterval = 10.0, completion: @escaping ([CBPeripheral]) -> Void) {
		guard !centralManager.isScanning else {
			print("Scan already in progress.")
			// Optionally call completion immediately with current discoveries or wait
			// For simplicity, we just return here.
			return
		}

		print("Scan requested.")
		self.discoveryCompletion = completion
		self.discoveredPeripherals.removeAll() // Clear previous results
		self.scanRequested = true

		// Check if Bluetooth is ready, otherwise wait for state update
		if centralManager.state == .poweredOn {
			print("Bluetooth is already powered on. Starting scan.")
			startActualScan(timeout: timeout)
		} else {
			print("Bluetooth is not ready (\(centralManager.state)). Waiting for state update.")
			// Scan will be triggered by centralManagerDidUpdateState if state becomes .poweredOn
		}
	}

	/// Connects to a specific peripheral.
	/// - Parameters:
	///   - peripheral: The CBPeripheral to connect to.
	///   - completion: Optional handler called with connection success/failure status.
	func connect(to peripheral: CBPeripheral, completion: ((Bool, Error?) -> Void)? = nil) {
		guard !isConnecting else {
			print("Connection attempt already in progress for \(peripheral.name ?? "a peripheral").")
			return
		}

		// Disconnect from any currently connected peripheral first
		if let currentPeripheral = connectedPeripheral, currentPeripheral != peripheral {
			 print("Disconnecting from previous peripheral: \(currentPeripheral.name ?? "Unknown")")
			 disconnect() // Disconnect the old one
		}


		// Ensure we stop scanning before connecting
		if centralManager.isScanning {
			print("Stopping scan to initiate connection.")
			stopScan() // Clears discoveryCompletion
		}

		print("Connecting to \(peripheral.name ?? "Unknown")...")
		self.connectionCompletion = completion
		self.isConnecting = true
		self.connectedPeripheral = peripheral // Assign immediately for delegate methods
		self.connectedPeripheral?.delegate = self
		centralManager.connect(peripheral, options: nil)
	}

	/// Disconnects from the currently connected peripheral.
	func disconnect() {
		guard let peripheral = connectedPeripheral else {
			print("Not connected to any peripheral.")
			return
		}

		print("Disconnecting from \(peripheral.name ?? "Unknown")...")
		centralManager.cancelPeripheralConnection(peripheral)
		// Peripheral object is cleared in didDisconnectPeripheral delegate method
	}

	/// Reads the value from the specific moisture characteristic.
	/// Assumes the peripheral is connected and the characteristic has been discovered.
	/// - Parameter completion: Handler called with the characteristic data or nil on failure.
	func readMoistureValue(completion: @escaping (Data?) -> Void) {
		self.readCompletion = completion // Store completion handler

		guard let peripheral = connectedPeripheral, peripheral.state == .connected else {
			print("Error: Peripheral not connected.")
			completeRead(with: nil)
			return
		}

		guard let characteristic = findCharacteristic(uuid: moistureCharUUID, in: peripheral) else {
			print("Error: Moisture characteristic not found or service not discovered yet.")
			completeRead(with: nil)
			return
		}

		print("Reading value from characteristic: \(characteristic.uuid)")
		peripheral.readValue(for: characteristic)
	}

	// MARK: - Private Scan Method
	
	private func completeDiscovery() {
		// First collect all devices for debugging
		let allPeripherals = discoveredPeripherals
		
		// Filter for any of our target device names
		let matchingPeripherals = discoveredPeripherals.filter { peripheral in
			guard let name = peripheral.name?.lowercased() else { return false }
			
			// Check if the peripheral name contains any of our known device names
			return serverNames.contains { knownName in
				name.contains(knownName.lowercased())
			}
		}
		
		print("Scan complete. Found \(allPeripherals.count) total peripherals.")
		if !allPeripherals.isEmpty {
			print("All discovered devices:")
			allPeripherals.forEach { peripheral in
				print("  - \(peripheral.name ?? "Unnamed device") (\(peripheral.identifier))")
			}
		}
		
		print("Found \(matchingPeripherals.count) peripherals matching any known device name")
		
		DispatchQueue.main.async { [weak self] in // Ensure execution on main thread
			if matchingPeripherals.isEmpty && !allPeripherals.isEmpty {
				// If we found devices but none match our filter, return ALL devices
				// This helps during development/debugging
				print("No exact matches found, but returning all \(allPeripherals.count) discovered devices for selection")
				self?.discoveryCompletion?(allPeripherals)
			} else {
				self?.discoveryCompletion?(matchingPeripherals)
			}
			self?.discoveryCompletion = nil // Clear completion handler
			self?.discoveredPeripherals.removeAll() // Clear discovered list for next scan
		}
	}

	private func startActualScan(timeout: TimeInterval) {
		guard centralManager.state == .poweredOn else {
			 print("Error: Cannot start scan, Bluetooth is not powered on.")
			 scanRequested = false // Reset request if state is wrong
			 completeDiscovery() // Call completion with empty array
			 return
		}

		guard !centralManager.isScanning else {
			 print("Internal check: Already scanning.") // Should ideally be caught by public func
			 return
		}

		print("Starting actual scan for peripherals advertising service \(moistureServiceUUID)...")
		scanRequested = false // Reset flag as we are now starting

		print("Starting scan for ALL peripherals...")
		// Scan for all devices (null service UUID) in development to see what's available
		centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])

		// Start a timer to stop scanning after the timeout
		scanTimer?.invalidate() // Invalidate previous timer if any
		scanTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
			print("Scan timed out after \(timeout) seconds.")
			self?.stopScanAndCompleteDiscovery()
		}
	}

	private func stopScan() {
		if centralManager.isScanning {
			print("Stopping scan.")
			centralManager.stopScan()
			scanTimer?.invalidate()
			scanTimer = nil
		}
		scanRequested = false // Ensure request flag is off
	}

	private func stopScanAndCompleteDiscovery() {
		stopScan()
		completeDiscovery()
	}

	// Safely calls the read completion handler and cleans up
	private func completeRead(with data: Data?) {
		DispatchQueue.main.async { [weak self] in
			self?.readCompletion?(data)
			self?.readCompletion = nil
		}
	}

	// Safely calls the connection completion handler and cleans up
	private func completeConnection(success: Bool, error: Error?) {
		isConnecting = false // Reset connecting flag
		DispatchQueue.main.async { [weak self] in
			self?.connectionCompletion?(success, error)
			self?.connectionCompletion = nil
		}
	}


	// MARK: - Private Helper Methods

	/// Finds a specific characteristic within a connected peripheral's services.
	private func findCharacteristic(uuid: CBUUID, in peripheral: CBPeripheral) -> CBCharacteristic? {
		guard let services = peripheral.services else {
			return nil
		}

		for service in services {
			if let characteristics = service.characteristics {
				for characteristic in characteristics {
					if characteristic.uuid == uuid {
						return characteristic
					}
				}
			}
		}
		return nil
	}

	/// Resets internal state related to connection and discovery.
	private func resetConnectionState() {
		isConnecting = false
		connectedPeripheral = nil // Clear reference
		readCompletion = nil // Clear pending reads
		connectionCompletion = nil // Clear pending connection callback
		// Note: discoveryCompletion is handled by scan completion logic
	}

	// MARK: - CBCentralManagerDelegate Methods

	func centralManagerDidUpdateState(_ central: CBCentralManager) {
		switch central.state {
		case .poweredOn:
			print("Bluetooth state: Powered ON")
			// If a scan was requested while powered off, start it now
			if scanRequested {
				print("Scan was pending, starting now.")
				startActualScan(timeout: 10.0) // Use default or stored timeout
			}
		case .poweredOff:
			print("Bluetooth state: Powered OFF")
			// Handle UI updates, stop actions
			stopScan()
			completeDiscovery() // Complete any pending scan with empty results
			resetConnectionState() // Reset if we were connected/connecting
			// Potentially alert the user
		case .resetting:
			print("Bluetooth state: Resetting")
			// Wait for next state update (.poweredOn or .poweredOff)
			stopScan() // Stop actions while resetting
			resetConnectionState()
		case .unauthorized:
			print("Bluetooth state: Unauthorized")
			// Alert user app needs Bluetooth permission
			stopScan()
			completeDiscovery()
			resetConnectionState()
		case .unsupported:
			print("Bluetooth state: Unsupported")
			// Alert user device doesn't support BLE
			stopScan()
			completeDiscovery()
			resetConnectionState()
		case .unknown:
			print("Bluetooth state: Unknown")
			// Wait for a definitive state update
		@unknown default:
			print("Bluetooth state: Encountered unknown state")
		}
	}

	func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
		// Optional: Filter by RSSI here if needed
		// print("Discovered: \(peripheral.name ?? "Unknown") RSSI: \(RSSI)")

		// Add to list if not already present
		if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
			 print("Adding discovered peripheral: \(peripheral.name ?? "Unknown") (\(peripheral.identifier.uuidString))")
			 discoveredPeripherals.append(peripheral)
		}

		// Optional: Check if this is the target device and stop scanning early
		// if let name = peripheral.name, name.contains(serverName) {
		//    print("Target device '\(serverName)' found. Stopping scan early.")
		//    stopScanAndCompleteDiscovery()
		// }
		// Note: Current logic waits for timeout or manual stop to return *all* matching devices.
		// If you want to connect to the *first* one found, you'd call connect() here
		// and modify the completion logic.
	}

	func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
		print("Successfully connected to \(peripheral.name ?? "Unknown").")
		isConnecting = false // Connection attempt finished

		// Hold a strong reference
		connectedPeripheral = peripheral
		connectedPeripheral?.delegate = self

		// Discover the specific service we need
		print("Discovering services...")
		peripheral.discoverServices([moistureServiceUUID])

		completeConnection(success: true, error: nil)
	}

	func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
		print("Failed to connect to \(peripheral.name ?? "Unknown"): \(error?.localizedDescription ?? "Unknown error")")
		if connectedPeripheral == peripheral { // Ensure we clear the correct peripheral reference
		   resetConnectionState()
		}
		completeConnection(success: false, error: error)
	}

	func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
		if let error = error {
			print("Disconnected from \(peripheral.name ?? "Unknown") with error: \(error.localizedDescription)")
		} else {
			print("Disconnected cleanly from \(peripheral.name ?? "Unknown").")
		}

		// Clear reference and state if this was the connected peripheral
		if connectedPeripheral == peripheral {
			resetConnectionState()
			// Notify ViewModel or delegate about disconnection if needed
		} else {
			 print("Disconnected from a peripheral that wasn't the primary connected one.")
		}
	}


	// MARK: - CBPeripheralDelegate Methods

	func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
		if let error = error {
			print("Error discovering services on \(peripheral.name ?? "Unknown"): \(error.localizedDescription)")
			// Maybe disconnect or retry?
			disconnect() // Simple cleanup
			return
		}

		guard let services = peripheral.services else {
			print("No services discovered for \(peripheral.name ?? "Unknown").")
			return
		}

		print("Discovered services: \(services.map { $0.uuid.uuidString })")

		for service in services {
			if service.uuid == moistureServiceUUID {
				print("Found target service \(service.uuid). Discovering characteristics...")
				peripheral.discoverCharacteristics([moistureCharUUID], for: service)
				return // Found our service, no need to check others
			}
		}
		print("Target service \(moistureServiceUUID) not found.")
		// Handle case where expected service isn't present
	}

	func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
		if let error = error {
			print("Error discovering characteristics for service \(service.uuid) on \(peripheral.name ?? "Unknown"): \(error.localizedDescription)")
			return
		}

		guard let characteristics = service.characteristics else {
			print("No characteristics found for service \(service.uuid).")
			return
		}

		print("Discovered characteristics for service \(service.uuid): \(characteristics.map { $0.uuid.uuidString })")

		var foundTarget = false
		for characteristic in characteristics {
			if characteristic.uuid == moistureCharUUID {
				print("Found target characteristic \(characteristic.uuid).")
				foundTarget = true
				// Optional: Enable notifications if the peripheral sends updates automatically
				// if characteristic.properties.contains(.notify) {
				//    print("Characteristic supports notify. Subscribing...")
				//    peripheral.setNotifyValue(true, for: characteristic)
				// }
				// You might want to call a delegate/completion here indicating readiness to read/write
			}
		}
		if !foundTarget {
			 print("Target characteristic \(moistureCharUUID) not found in service \(service.uuid).")
		}
	}

	func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
		if let error = error {
			print("Error receiving value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
			if characteristic.uuid == moistureCharUUID {
				completeRead(with: nil) // Call completion with nil on error for the target characteristic
			}
			return
		}

		guard let data = characteristic.value else {
			print("Received notification/read response for \(characteristic.uuid) but data is nil.")
			 if characteristic.uuid == moistureCharUUID {
				completeRead(with: nil)
			}
			return
		}

		// If this update is for the characteristic we tried to read, call completion
		if characteristic.uuid == moistureCharUUID {
			 print("Received value for moisture characteristic: \(data.count) bytes.")
			 // Optional: Log hex representation
			 // print("Data (hex): \(data.map { String(format: "%02X", $0) }.joined())")
			 completeRead(with: data)
		} else {
			 print("Received value for unexpected characteristic: \(characteristic.uuid)")
			 // Handle data from other characteristics if needed
		}
	}

	// Optional: Handle notification state changes if you use setNotifyValue
	func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
		if let error = error {
			print("Error changing notification state for \(characteristic.uuid): \(error.localizedDescription)")
			return
		}

		if characteristic.isNotifying {
			print("Successfully subscribed to notifications for \(characteristic.uuid)")
		} else {
			print("Successfully unsubscribed from notifications for \(characteristic.uuid)")
		}
	}

	// Optional: Handle write confirmations if you add write functionality
	// func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) { ... }
}
