//
//  bonsaiApp.swift
//  bonsai
//
//  Created by Jet Chiang on 2025-03-15.
//

import SwiftUI
import SwiftData

@main
struct BonsaiApp: App {
	var sharedModelContainer: ModelContainer = {
		let schema = Schema([
			MoistureReading.self,   // Stores soil moisture data
			BluetoothDevice.self    // Stores paired Bluetooth device info
		])
		let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

		do {
			return try ModelContainer(for: schema, configurations: [modelConfiguration])
		} catch {
			fatalError("Could not create ModelContainer: \(error)")
		}
	}()

	@StateObject var appViewModel = AppViewModel()

	var body: some Scene {
		WindowGroup {
			ContentView()
				.environmentObject(appViewModel) // Inject AppViewModel into all views
		}
		.modelContainer(sharedModelContainer) // Inject ModelContainer for SwiftData
	}
}
