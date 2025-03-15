//
//  MoistureViewModel.swift
//  bonsai
//
//  Created by Jet Chiang on 2025-03-15.
//

import Foundation
import SwiftData

class MoistureViewModel: ObservableObject {
	@Published var latestMoisture: Double = 0.0
	@Published var moistureHistory: [MoistureReading] = []
	
	private var modelContext: ModelContext?

	// Inject SwiftData ModelContext
	func setContext(_ context: ModelContext) {
		self.modelContext = context
		fetchMoistureHistory()
	}

	// Fetch past moisture readings from SwiftData
	func fetchMoistureHistory() {
		guard let context = modelContext else { return }
		
		let fetchDescriptor = FetchDescriptor<MoistureReading>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
		
		if let readings = try? context.fetch(fetchDescriptor) {
			moistureHistory = readings
			latestMoisture = readings.first?.moistureLevel ?? 0.0
		}
	}

	// Save a new moisture reading
	func saveMoistureReading(value: Double) {
		guard let context = modelContext else { return }
		let newReading = MoistureReading(timestamp: Date(), moistureLevel: value)
		context.insert(newReading)
		try? context.save()
		fetchMoistureHistory() // Update UI
	}
}
