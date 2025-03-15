//
//  BluetoothListView.swift
//  bonsai
//
//  Created by Jet Chiang on 2025-03-15.
//

import SwiftUI
import CoreBluetooth

struct BluetoothListView: View {
	@ObservedObject var bluetoothVM: BluetoothViewModel
	@Environment(\.presentationMode) var presentationMode

	var body: some View {
		VStack {
			Text("Select a Device")
				.font(.title2)
				.padding()

			// If scanning, show a loading indicator
			if bluetoothVM.isScanning {
				ProgressView("Scanning...")
			} else if bluetoothVM.discoveredDevices.isEmpty {
				Text("No devices found. Try scanning again.")
					.foregroundColor(.gray)
					.padding()
			} else {
				List(bluetoothVM.discoveredDevices, id: \.identifier) { device in
					Button(action: {
						bluetoothVM.connectToDevice(device)
						presentationMode.wrappedValue.dismiss() // Close the list after connecting
					}) {
						HStack {
							Text(device.name ?? "Unknown")
							Spacer()
							Image(systemName: "chevron.right")
								.foregroundColor(.gray)
						}
					}
				}
			}

			Spacer()

			// Rescan button
			Button(action: {
				bluetoothVM.startScanning()
			}) {
				Text(bluetoothVM.isScanning ? "Scanning..." : "Rescan")
					.bold()
					.padding()
			}
		}
		.padding()
	}
}

#Preview {
	BluetoothListView()
}
