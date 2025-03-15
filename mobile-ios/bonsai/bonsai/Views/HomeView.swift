//
//  HomeView.swift
//  bonsai
//
//  Created by Jet Chiang on 2025-03-15.
//

import SwiftUI
import SwiftData

struct HomeView: View {
	@StateObject private var bluetoothVM = BluetoothViewModel()
	@Environment(\.modelContext) private var modelContext

	var body: some View {
			NavigationView {
				VStack {
					// If no remembered device, show BluetoothListView
					if bluetoothVM.pairedDevice == nil {
						BluetoothListView(bluetoothVM: bluetoothVM)
					} else {
						// If a device is remembered, show a navigation button to MoistureDataView
						NavigationLink(destination: MoistureDataView()) {
							VStack {
								Text("Connected to \(bluetoothVM.pairedDevice?.name ?? "Unknown")")
									.bold()
									.padding()
								Text("Tap to view moisture data")
									.foregroundColor(.gray)
							}
						}
						.padding()
					}
				}
				.padding()
				.onAppear {
					bluetoothVM.setContext(modelContext) // Load remembered device
				}
				.navigationTitle("Bonsai Soil Sensor")
			}
		}
}

struct HeaderView: View {
	var body: some View {
		HStack {
			Text("Bonsai Soil Sensor")
				.font(.title)
				.bold()
			Spacer()
			NavigationLink(destination: SettingsView()) {
				Image(systemName: "gearshape.fill")
			}
		}
		.padding()
	}
}
