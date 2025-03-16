//
//  ContentView.swift
//  testing-bluetooth
//
//  Created by Jet Chiang on 2025-03-16.
//

import SwiftUI
import CoreBluetooth

import SwiftUI

struct ContentView: View {
	@State private var receivedMessage: String = "Waiting for message..."
	private let bleManager = BLEPeripheralManager()

	var body: some View {
		VStack(spacing: 20) {
			Spacer()
			// Icon with a subtle shadow
			Image(systemName: "drop.circle.fill")
				.resizable()
				.frame(width: 80, height: 80)
				.foregroundColor(.blue)
				.shadow(radius: 5)

			// Title
			Text("Bonsai Health Monitor")
				.font(.title)
				.bold()
				.foregroundColor(.primary)

			// Received Message Section
			VStack {
				Text(receivedMessage.isEmpty ? "No Data Received" : receivedMessage)
					.font(.title3)
					.padding()
					.frame(maxWidth: .infinity)
					.background(Color.blue.opacity(0.2))
					.cornerRadius(12)
					.shadow(radius: 2)
					.foregroundColor(.blue)
			}
			.frame(maxWidth: 300)

			// Loading indicator when waiting for message
			if receivedMessage == "Waiting for message..." {
				ProgressView()
					.padding()
			}

			Spacer()
		}
		.padding()
		.onAppear {
			bleManager.startAdvertising { message in
				self.receivedMessage = message
			}
		}
	}
}

#Preview {
	ContentView()
}
