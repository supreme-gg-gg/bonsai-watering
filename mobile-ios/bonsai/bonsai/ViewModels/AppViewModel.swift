//
//  AppViewModel.swift
//  bonsai
//
//  Created by Jet Chiang on 2025-03-15.
//

import Foundation
import SwiftData

class AppViewModel: ObservableObject {
	@Published var pairedDevice: BluetoothDevice?

	func savePairedDevice(_ device: BluetoothDevice, context: ModelContext) {
		pairedDevice = device
		context.insert(device)
		try? context.save()
	}

	func clearPairedDevice(context: ModelContext) {
		if let device = pairedDevice {
			context.delete(device)
			try? context.save()
			pairedDevice = nil
		}
	}

	func fetchPairedDevice(from context: ModelContext) {
		// Fetch the paired device from the database
		// tells SwiftData to fetch instances of BluetoothDevice
		let fetchDescriptor = FetchDescriptor<BluetoothDevice>()
		if let device = try? context.fetch(fetchDescriptor).first { // first result is pairedDevice
			pairedDevice = device
		}
	}
}
