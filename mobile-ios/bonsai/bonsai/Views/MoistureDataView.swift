//
//  MoistureDataView.swift
//  bonsai
//
//  Created by Jet Chiang on 2025-03-15.
//

import SwiftUI
import Charts

struct MoistureDataView: View {
	@StateObject private var moistureVM = MoistureViewModel()
	@Environment(\.modelContext) private var modelContext

	var body: some View {
		VStack {
			Text("Soil Moisture")
				.font(.title)
				.bold()
				.padding()

			Text("Latest Reading: \(String(format: "%.2f", moistureVM.latestMoisture))%")
				.font(.headline)
				.padding()

			// Moisture History Chart
			if !moistureVM.moistureHistory.isEmpty {
				Chart(moistureVM.moistureHistory) { data in
					LineMark(
						x: .value("Time", data.timestamp),
						y: .value("Moisture", data.moistureLevel)
					)
					.foregroundStyle(.blue)
				}
				.frame(height: 250)
				.padding()
			} else {
				Text("No moisture data available")
					.foregroundColor(.gray)
					.padding()
			}

			Spacer()
		}
		.padding()
		.onAppear {
			moistureVM.setContext(modelContext) // Inject SwiftData context
		}
	}
}

#Preview {
    MoistureDataView()
}
