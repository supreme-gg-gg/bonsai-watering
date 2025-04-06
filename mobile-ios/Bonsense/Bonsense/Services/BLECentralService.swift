//
//  BLECentralManager.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-04-05.
//

import Foundation
import CoreBluetooth

// MARK: - Delegate Protocol
protocol BLECentralManagerDelegate: AnyObject {
	func bleManagerDidUpdateState(_ state: CBManagerState)
	func bleManagerDidDiscoverPeripherals(_ peripherals: [CBPeripheral]) // Primarily for UI listing
	func bleManagerDidConnect(to peripheral: CBPeripheral)
	func bleManagerIsReadyToRead(from peripheral: CBPeripheral) // Indicates service/characteristic discovery is complete
	func bleManager(didFailToConnect peripheral: CBPeripheral, error: Error?)
	func bleManager(didDisconnect peripheral: CBPeripheral, error: Error?)
	func bleManager(didReceiveData data: Data?, for characteristicUUID: CBUUID, error: Error?)
}

// MARK: - BLECentralManager Class
class BLECentralManager: NSObject {

	// MARK: - Properties
	private var centralManager: CBCentralManager!
	private var connectedPeripheral: CBPeripheral?
	private var discoveredPeripherals: [CBPeripheral] = [] // Store all discovered peripherals during a scan session
	private var targetPeripheral: CBPeripheral? // The specific peripheral we intend to connect to or are connected to

	// Service and characteristic UUIDs - Ensure these are correct
	let moistureServiceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")
	let moistureCharUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef1")

	// Device name to search for
	let serverName = "BonsaiPeripheral"

	// State Tracking
	private var scanTimer: Timer?
	private var isConnecting = false
	private var scanTimeout: TimeInterval = 10.0 // Store timeout duration

	// Delegate
	weak var delegate: BLECentralManagerDelegate?

	// MARK: - Initialization
	override init() {
		super.init()
		// Initialize on main queue is standard practice
		centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
		log("BLECentralManager initialized.")
	}

	// MARK: - Public Accessors
	var currentBluetoothState: CBManagerState {
		return centralManager.state
	}

	var isScanning: Bool {
		return centralManager.isScanning
	}

	// MARK: - Public Methods: Scanning
	/// Starts scanning for peripherals. Connects immediately if target device is found.
	/// Calls delegate `bleManagerDidDiscoverPeripherals` when scan finishes (timeout or stopped).
	/// - Parameter timeout: Duration in seconds to scan. Defaults to 10 seconds.
	func startScan(timeout: TimeInterval = 10.0) {
		guard centralManager.state == .poweredOn else {
			log("Cannot scan, Bluetooth is not powered on (\(centralManager.state)).")
			// Delegate will be notified of state change via centralManagerDidUpdateState
			return
		}
		guard !centralManager.isScanning else {
			log("Scan already in progress.")
			return
		}

		log("Starting scan for peripherals (Timeout: \(timeout)s)...")
		self.scanTimeout = timeout
		self.discoveredPeripherals.removeAll() // Clear results from previous scan
		self.targetPeripheral = nil // Clear potential target from previous scan
		isConnecting = false // Reset connection flag

		// Scan for devices advertising the specific service UUID for efficiency,
		// or nil to discover all devices (useful for debugging).
		// centralManager.scanForPeripherals(withServices: [moistureServiceUUID], options: nil)
		 centralManager.scanForPeripherals(withServices: nil, options: nil) // Scan for all to allow selection

		// Start timeout timer
		scanTimer?.invalidate()
		scanTimer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(scanDidTimeout), userInfo: nil, repeats: false)
	}

	/// Stops the ongoing peripheral scan.
	func stopScan() {
		guard centralManager.isScanning else { return }
		log("Stopping scan.")
		centralManager.stopScan()
		scanTimer?.invalidate()
		scanTimer = nil
		// Notify delegate with current findings when scan is explicitly stopped or times out
		delegate?.bleManagerDidDiscoverPeripherals(discoveredPeripherals)
	}

	@objc private func scanDidTimeout() {
		guard centralManager.isScanning else { return }
		log("Scan timed out after \(scanTimeout) seconds.")
		stopScan() // This will also call the delegate
	}

	// MARK: - Public Methods: Connection
	/// Connects to a specific peripheral.
	/// - Parameter peripheral: The CBPeripheral to connect to.
	func connect(to peripheral: CBPeripheral) {
		guard !isConnecting else {
			log("Connection attempt already in progress.")
			return
		}
		guard centralManager.state == .poweredOn else {
			 log("Cannot connect, Bluetooth not powered on.")
			 delegate?.bleManager(didFailToConnect: peripheral, error: NSError(domain: "BLEError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Bluetooth is not powered on."]))
			 return
		}

		// Disconnect if already connected to a different peripheral
		if let currentConnected = connectedPeripheral, currentConnected != peripheral {
			log("Disconnecting from previous peripheral: \(currentConnected.identifier)")
			disconnect() // Disconnect the old one first
		}

		// Stop scanning if we are connecting manually (might have been scanning)
		if centralManager.isScanning {
			log("Stopping scan to initiate connection.")
			stopScan()
		}

		log("Connecting to \(peripheral.name ?? "Unknown") (\(peripheral.identifier))...")
		isConnecting = true
		targetPeripheral = peripheral // Store the target device
		targetPeripheral?.delegate = self // Set delegate *before* connecting
		centralManager.connect(peripheral, options: nil)
	}

	/// Disconnects from the currently connected peripheral.
	func disconnect() {
		guard let peripheral = connectedPeripheral ?? targetPeripheral else { // Check both connected and target (if connection failed mid-way)
			log("Not connected to any peripheral or no target specified.")
			return
		}

		log("Disconnecting from \(peripheral.name ?? "Unknown")...")
		// Cancel connection if it was in progress or established
		centralManager.cancelPeripheralConnection(peripheral)
		// State cleanup happens in didDisconnectPeripheral delegate method
	}

	// MARK: - Public Methods: Data Interaction
	/// Reads the value from the specific moisture characteristic.
	/// Assumes connection and service/characteristic discovery are complete.
	func readMoistureValue() {
		guard let peripheral = connectedPeripheral, peripheral.state == .connected else {
			log("Error: Peripheral not connected.")
			delegate?.bleManager(didReceiveData: nil, for: moistureCharUUID, error: NSError(domain: "BLEError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Peripheral not connected."]))
			return
		}

		guard let characteristic = findCharacteristic(uuid: moistureCharUUID, in: peripheral) else {
			log("Error: Moisture characteristic not found. Ensure services/characteristics are discovered.")
			delegate?.bleManager(didReceiveData: nil, for: moistureCharUUID, error: NSError(domain: "BLEError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Moisture characteristic not found."]))
			return
		}

		guard characteristic.properties.contains(.read) else {
			 log("Error: Moisture characteristic does not support reading.")
			 delegate?.bleManager(didReceiveData: nil, for: moistureCharUUID, error: NSError(domain: "BLEError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Characteristic does not support read."]))
			 return
		}


		log("Reading value from characteristic: \(characteristic.uuid)")
		peripheral.readValue(for: characteristic)
	}

	// MARK: - Private Helper Methods

	/// Finds a specific characteristic within a connected peripheral's discovered services.
	private func findCharacteristic(uuid: CBUUID, in peripheral: CBPeripheral) -> CBCharacteristic? {
		guard let services = peripheral.services else { return nil }

		return services.lazy
			.flatMap { $0.characteristics ?? [] }
			.first { $0.uuid == uuid }
	}

	/// Resets internal state related to the current connection/target.
	private func resetConnectionState(for peripheral: CBPeripheral?) {
		log("Resetting connection state for peripheral: \(peripheral?.identifier.uuidString ?? "None")")
		if connectedPeripheral == peripheral {
			connectedPeripheral?.delegate = nil
			connectedPeripheral = nil
		}
		if targetPeripheral == peripheral {
			targetPeripheral?.delegate = nil // Ensure delegate is cleared even if connection failed
			targetPeripheral = nil
		}
		isConnecting = false
	}

	/// Simple logger
	private func log(_ message: String) {
		// Replace with OSLog or conditional compilation if desired
		 print("[BLEManager] \(message)")
	}
}

// MARK: - CBCentralManagerDelegate Methods
extension BLECentralManager: CBCentralManagerDelegate {

	func centralManagerDidUpdateState(_ central: CBCentralManager) {
		log("Bluetooth state changed: \(central.state)")
		delegate?.bleManagerDidUpdateState(central.state)

		switch central.state {
		case .poweredOn:
			// If needed, could trigger an automatic scan here, but typically UI driven
			break
		case .poweredOff, .resetting, .unauthorized, .unsupported, .unknown:
			// Stop scan if active
			stopScan()
			// If we were connected or connecting, the system handles disconnection,
			// which will trigger didDisconnectPeripheral. Clean up our state there.
			if let connected = connectedPeripheral {
				 // Force cleanup if system doesn't send disconnect event quickly
				 resetConnectionState(for: connected)
				 delegate?.bleManager(didDisconnect: connected, error: NSError(domain: "BLEError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Bluetooth became unavailable."]))
			} else if let target = targetPeripheral, isConnecting {
				 resetConnectionState(for: target)
				 delegate?.bleManager(didFailToConnect: target, error: NSError(domain: "BLEError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Bluetooth became unavailable during connection attempt."]))
			}

		@unknown default:
			log("Encountered unknown Bluetooth state.")
		}
	}

	func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
		// Add to list if unique
		if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
			log("Discovered: \(peripheral.name ?? "Unknown") (\(peripheral.identifier)) RSSI: \(RSSI)")
			discoveredPeripherals.append(peripheral)
			// Optionally update delegate immediately with the growing list, or wait for scan timeout/stop
			// delegate?.bleManagerDidDiscoverPeripherals(discoveredPeripherals) // Uncomment for live updates
		}

		if let name = peripheral.name, name.lowercased().contains(serverName.lowercased()) {
			log("Target device '\(serverName)' found. Attempting connection...")
			stopScan() // Stop scanning
			connect(to: peripheral) // Attempt to connect immediately
			// Note: The delegate `bleManagerDidDiscoverPeripherals` will be called by `stopScan`.
		}
	}

	func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
		log("Successfully connected to \(peripheral.name ?? "Unknown").")
		isConnecting = false
		connectedPeripheral = peripheral // Hold reference
		connectedPeripheral?.delegate = self // Ensure delegate is set (should be already by connect method)
		targetPeripheral = nil // Clear target as we are now connected

		delegate?.bleManagerDidConnect(to: peripheral)

		// Discover the specific service we need
		log("Discovering services...")
		peripheral.discoverServices([moistureServiceUUID])
	}

	func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
		log("Failed to connect to \(peripheral.name ?? "Unknown"): \(error?.localizedDescription ?? "Unknown error")")
		resetConnectionState(for: peripheral) // Use the specific peripheral it failed for
		delegate?.bleManager(didFailToConnect: peripheral, error: error)
	}

	func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
		if let error = error {
			log("Disconnected from \(peripheral.name ?? "Unknown") with error: \(error.localizedDescription)")
		} else {
			log("Disconnected cleanly from \(peripheral.name ?? "Unknown").")
		}

		// Clear reference and state only if this was the actively connected peripheral
		if connectedPeripheral == peripheral {
			 resetConnectionState(for: peripheral)
			 delegate?.bleManager(didDisconnect: peripheral, error: error)
		} else {
			 log("Disconnected from a peripheral (\(peripheral.identifier)) that wasn't the primary connected one (was \(connectedPeripheral?.identifier.uuidString ?? "None")). Maybe the targetPeripheral during a failed connection.")
			 // Ensure target peripheral state is also cleaned up if it matches
			 if targetPeripheral == peripheral {
				 resetConnectionState(for: peripheral)
				 // We might not need to call the delegate here if didFailToConnect was already called
			 }
		}
	}
}

// MARK: - CBPeripheralDelegate Methods
extension BLECentralManager: CBPeripheralDelegate {

	func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
		if let error = error {
			log("Error discovering services on \(peripheral.name ?? "Unknown"): \(error.localizedDescription)")
			// Consider disconnecting or just reporting error
			disconnect() // Simple cleanup: disconnect on service discovery error
			delegate?.bleManager(didFailToConnect: peripheral, error: error) // Report as connection failure phase
			return
		}

		guard let services = peripheral.services, !services.isEmpty else {
			log("No services discovered for \(peripheral.name ?? "Unknown").")
			disconnect() // Disconnect if no services found
			 delegate?.bleManager(didFailToConnect: peripheral, error: NSError(domain: "BLEError", code: 6, userInfo: [NSLocalizedDescriptionKey: "No services found."]))
			return
		}

		log("Discovered services: \(services.map { $0.uuid.uuidString }) for \(peripheral.identifier)")

		// Find the specific service and discover characteristics
		if let targetService = services.first(where: { $0.uuid == moistureServiceUUID }) {
			log("Found target service \(targetService.uuid). Discovering characteristics...")
			peripheral.discoverCharacteristics([moistureCharUUID], for: targetService)
		} else {
			log("Target service \(moistureServiceUUID) not found.")
			disconnect() // Disconnect if target service is missing
			delegate?.bleManager(didFailToConnect: peripheral, error: NSError(domain: "BLEError", code: 7, userInfo: [NSLocalizedDescriptionKey: "Required service not found."]))
		}
	}

	func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
		if let error = error {
			log("Error discovering characteristics for service \(service.uuid): \(error.localizedDescription)")
			 disconnect() // Disconnect on characteristic discovery error
			 delegate?.bleManager(didFailToConnect: peripheral, error: error)
			return
		}

		guard let characteristics = service.characteristics, !characteristics.isEmpty else {
			log("No characteristics found for service \(service.uuid).")
			 disconnect() // Disconnect if no characteristics found
			 delegate?.bleManager(didFailToConnect: peripheral, error: NSError(domain: "BLEError", code: 8, userInfo: [NSLocalizedDescriptionKey: "No characteristics found for service \(service.uuid)."]))

			return
		}

		log("Discovered characteristics for service \(service.uuid): \(characteristics.map { $0.uuid.uuidString })")

		// Check if our target characteristic is present
		if characteristics.contains(where: { $0.uuid == moistureCharUUID }) {
			log("Found target characteristic \(moistureCharUUID). Ready for interaction.")
			// Notify the delegate that the peripheral is ready for read/write operations
			delegate?.bleManagerIsReadyToRead(from: peripheral)
		} else {
			log("Target characteristic \(moistureCharUUID) not found in service \(service.uuid).")
			disconnect() // Disconnect if target characteristic is missing
			delegate?.bleManager(didFailToConnect: peripheral, error: NSError(domain: "BLEError", code: 9, userInfo: [NSLocalizedDescriptionKey: "Required characteristic not found."]))
		}
	}

	func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
		 // Pass the result (data or error) to the delegate
		 delegate?.bleManager(didReceiveData: characteristic.value, for: characteristic.uuid, error: error)

		if let error = error {
			log("Error reading value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
			return // Delegate already notified
		}
		guard let data = characteristic.value else {
			log("Received nil data for characteristic \(characteristic.uuid).")
			return // Delegate already notified
		}
		log("Received \(data.count) bytes for characteristic \(characteristic.uuid).")
	}

	// Optional: Implement other CBPeripheralDelegate methods as needed (didWriteValueFor, didUpdateNotificationStateFor, etc.)
}

// MARK: - CBManagerState Extension for Logging
extension CBManagerState: CustomStringConvertible {
	public var description: String {
		switch self {
		case .poweredOn: return "Powered On"
		case .poweredOff: return "Powered Off"
		case .resetting: return "Resetting"
		case .unauthorized: return "Unauthorized"
		case .unsupported: return "Unsupported"
		case .unknown: return "Unknown"
		@unknown default: return "Unknown State"
		}
	}
}
