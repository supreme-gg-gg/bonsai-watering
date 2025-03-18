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
				
				// Try to parse a water level percentage from the message
				if let percentage = Double(message.trimmingCharacters(in: .whitespacesAndNewlines)) {
					// Ensure percentage is within 0-100 range
					let clampedPercentage = min(max(percentage, 0), 100)
					self?.waterLevel = WaterLevel(percentage: clampedPercentage)
					self?.navigateToResult = true
				} else {
					// If parsing fails, set a default value
					print("Warning: Could not parse a valid percentage from: \(message)")
					self?.waterLevel = WaterLevel(percentage: 50) // Default value
					self?.navigateToResult = true
				}
				
				self?.isConnected = true
			}
		}
		
		isAdvertising = true
	}
}
