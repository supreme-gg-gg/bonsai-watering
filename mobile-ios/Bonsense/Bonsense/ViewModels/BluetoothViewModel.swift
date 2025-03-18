//
//  BluetoothViewModel.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-03-17.
//

import Foundation
import CoreBluetooth

class BluetoothViewModel: ObservableObject {
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
