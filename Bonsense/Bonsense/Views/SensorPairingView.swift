//
//  SensorPairingView.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-03-17.
//

import SwiftUI

struct SensorPairingView: View {
	@EnvironmentObject var bluetoothViewModel: BLECentralViewModel
	@Environment(\.presentationMode) var presentationMode

	var body: some View {
		ZStack {
			BonsaiTheme.backgroundGradient()
				.ignoresSafeArea()

			VStack(spacing: 25) {
				// TITLE
				Text("Sensor Connection")
					.font(BonsaiTheme.titleFont)
					.foregroundColor(BonsaiTheme.primaryGreen)
					.padding(.top)

				if bluetoothViewModel.isScanning || bluetoothViewModel.isConnecting {
					// SCANNING OR CONNECTING INDICATOR
					activityIndicatorView
				} else if bluetoothViewModel.discoveredDevicesDisplay.isEmpty {
					// NO DEVICES FOUND (after scan finished)
					noDevicesView
				} else {
					// DEVICE SELECTION LIST
					deviceSelectionView
				}

				// STATUS CARD - Always visible, updates based on VM state
				connectionStatusCard

				Spacer()

				NavigationLink(
					destination: SensorResultView(viewModel: ResultViewModel(waterLevel: bluetoothViewModel.waterLevel ?? WaterLevel(percentage: 0)))
						.environmentObject(bluetoothViewModel),
					isActive: $bluetoothViewModel.navigateToResult
				) {
					EmptyView()
				}
			}
			.padding()
		}
		.navigationBarBackButtonHidden(true)
		.navigationBarItems(leading: backButton)
		 .onAppear {
		     if bluetoothViewModel.canScan && !bluetoothViewModel.isConnected && bluetoothViewModel.discoveredDevicesDisplay.isEmpty {
		         bluetoothViewModel.startScanning()
		     }
		 }
	}

	// MARK: - Component Views

	private var backButton: some View {
		Button(action: {
			// Stop scanning or disconnect on leaving
			 if bluetoothViewModel.isScanning { bluetoothViewModel.stopScanning() }
			 if bluetoothViewModel.isConnected { bluetoothViewModel.disconnect() }
			presentationMode.wrappedValue.dismiss()
		}) {
			HStack {
				Image(systemName: "chevron.left")
				Text("Back")
			}
			.foregroundColor(BonsaiTheme.primaryGreen)
		}
	}

	/// Shows activity for scanning or connecting states.
	private var activityIndicatorView: some View {
		VStack(spacing: 20) {
			ZStack {
				Circle()
					.fill(BonsaiTheme.sandBeige)
					.frame(width: 200, height: 200)
					.shadow(color: BonsaiTheme.earthBrown.opacity(0.3), radius: 10)

				// Show checkmark only when fully connected AND not scanning/connecting anymore
				if bluetoothViewModel.isConnected && !bluetoothViewModel.isConnecting && !bluetoothViewModel.isScanning {
					Image(systemName: "checkmark.circle.fill")
						.resizable()
						.scaledToFit()
						.foregroundColor(BonsaiTheme.primaryGreen)
						.frame(width: 100, height: 100)
				} else {
					// Show progress spinner during scanning or connecting
					ProgressView()
						.scaleEffect(2)
						.progressViewStyle(CircularProgressViewStyle(tint: BonsaiTheme.primaryGreen))
				}
			}

			Text(statusTextForActivity)
				.font(BonsaiTheme.headlineFont)
				.foregroundColor(BonsaiTheme.earthBrown)
		}
	}

	/// Computes the text to display below the activity indicator.
	private var statusTextForActivity: String {
		if bluetoothViewModel.isConnecting {
			return "Connecting..."
		} else if bluetoothViewModel.isScanning {
			return "Searching for devices..."
		} else if bluetoothViewModel.isConnected {
			 return "Connected"
		} else {
			return "Loading..."
		}
	}

	private var noDevicesView: some View {
		VStack(spacing: 15) {
			Image(systemName: "network.slash")
				.font(.system(size: 50))
				.foregroundColor(.gray)

			Text("No Devices Found")
				.font(BonsaiTheme.headlineFont)
				.foregroundColor(BonsaiTheme.earthBrown)

			Text(bluetoothViewModel.message)
				.font(BonsaiTheme.bodyFont)
				.foregroundColor(.secondary)
				.multilineTextAlignment(.center)
				.padding(.horizontal)

			scanAgainButton(fullWidth: true)
				.padding(.horizontal)
				.padding(.top, 10)
		}
		.padding()
	}

	private var deviceSelectionView: some View {
		VStack(spacing: 15) {
			Text("Select a Device")
				.font(BonsaiTheme.headlineFont)
				.foregroundColor(BonsaiTheme.earthBrown)

			ScrollView {
				VStack(spacing: 12) {
					// Use discoveredDevicesDisplay (the String array)
					ForEach(0..<bluetoothViewModel.discoveredDevicesDisplay.count, id: \.self) { index in
						deviceButton(at: index)
					}
				}
				.padding(.horizontal)
				.padding(.vertical)
			}
			.frame(maxHeight: 300) // Limit height
			.background(
				RoundedRectangle(cornerRadius: 15)
					.fill(Color.white.opacity(0.4))
					.shadow(color: Color.black.opacity(0.05), radius: 5)
			)

			scanAgainButton(fullWidth: false)
				.padding(.top, 10)
		}
	}

	private func deviceButton(at index: Int) -> some View {
		// Get the display name from the ViewModel's array
		let deviceName = bluetoothViewModel.discoveredDevicesDisplay[index]
		let isRecommended = deviceName.contains("★") // Check for the recommendation marker

		return Button(action: {
			// Call connect using the index, ViewModel maps it to the CBPeripheral
			bluetoothViewModel.connectToPeripheral(at: index)
		}) {
			HStack {
				Image(systemName: isRecommended ? "star.fill" : "wave.3.right")
					.foregroundColor(isRecommended ? .orange : BonsaiTheme.primaryGreen)

				Text(deviceName.replacingOccurrences(of: "★ ", with: "")) // Display name without the marker
					.lineLimit(1)
					.foregroundColor(BonsaiTheme.earthBrown)

				Spacer()

				Image(systemName: "chevron.right")
					.foregroundColor(BonsaiTheme.lightGreen)
			}
			.padding(.vertical, 12)
			.padding(.horizontal, 15)
			.background(
				RoundedRectangle(cornerRadius: 12)
					.fill(isRecommended ? BonsaiTheme.sandBeige.opacity(0.8) : Color.white)
					.shadow(color: Color.black.opacity(0.08), radius: 3)
			)
			.contentShape(Rectangle()) // Ensure the whole area is tappable
		}
		// Disable button if already connecting to prevent double taps
		.disabled(bluetoothViewModel.isConnecting)
	}

	private func scanAgainButton(fullWidth: Bool) -> some View {
		Button(action: {
			bluetoothViewModel.startScanning()
		}) {
			HStack {
				Image(systemName: "arrow.clockwise")
				Text("Scan Again")
			}
			.padding()
			.frame(maxWidth: fullWidth ? .infinity : 180)
			.background(bluetoothViewModel.canScan ? BonsaiTheme.skyBlue : Color.gray) // Use gray when disabled
			.foregroundColor(.white)
			.cornerRadius(15)
			.animation(.easeInOut, value: bluetoothViewModel.canScan) // Animate color change
		}
		// Disable button if scanning is not possible (BT off) or already scanning/connecting
		.disabled(!bluetoothViewModel.canScan || bluetoothViewModel.isScanning || bluetoothViewModel.isConnecting)
	}

	private var connectionStatusCard: some View {
		VStack(spacing: 10) {
			HStack {
				Image(systemName: statusIconName)
					.font(.system(size: 30))
					.foregroundColor(statusIconColor)
					.frame(width: 40, alignment: .center) // Give icon fixed width
					.animation(.easeInOut, value: bluetoothViewModel.isConnected)
					.animation(.easeInOut, value: bluetoothViewModel.isConnecting) // Animate based on connecting too


				VStack(alignment: .leading) {
					Text(statusTitle)
						.font(BonsaiTheme.bodyFont.bold())
						.animation(nil, value: UUID()) // Prevent default animation on text change if needed

					Text(bluetoothViewModel.message) // Display the message from VM
						.font(BonsaiTheme.bodyFont)
						.foregroundColor(.secondary)
						.lineLimit(2) // Allow message to wrap slightly
				}
				 Spacer() // Pushes content to the left
			}
			// Display error prominently if it exists
			 if let errorMsg = bluetoothViewModel.connectionError {
				 Text("Error: \(errorMsg)")
					 .font(.caption)
					 .foregroundColor(.red)
					 .frame(maxWidth: .infinity, alignment: .leading)
					 .padding(.top, 4)
			 }
		}
		.padding()
		.background(
			RoundedRectangle(cornerRadius: 15) // Slightly larger radius
				.fill(BonsaiTheme.sandBeige.opacity(0.6)) // Card background
				.shadow(color: Color.gray.opacity(0.15), radius: 4, x: 0, y: 2) // Softer shadow
		)
	}

	// Helper computed properties for status card clarity
	private var statusIconName: String {
		if bluetoothViewModel.connectionError != nil {
			return "exclamationmark.circle.fill"
		} else if bluetoothViewModel.isConnected {
			return "antenna.radiowaves.left.and.right.circle.fill"
		} else if bluetoothViewModel.isConnecting {
			return "hourglass.circle" // Indicate waiting/connecting
		} else {
			return "antenna.radiowaves.left.and.right.slash"
		}
	}

	private var statusIconColor: Color {
		if bluetoothViewModel.connectionError != nil {
			return .red
		} else if bluetoothViewModel.isConnected {
			return BonsaiTheme.primaryGreen
		} else if bluetoothViewModel.isConnecting {
			return .orange
		} else {
			return .gray // Neutral color when disconnected without error
		}
	}

	private var statusTitle: String {
		 if bluetoothViewModel.connectionError != nil {
			return "Connection Failed"
		} else if bluetoothViewModel.isConnected {
			return "Device Connected"
		} else if bluetoothViewModel.isConnecting {
			return "Connecting..."
		} else {
			return "Not Connected"
		}
	}

}

// MARK: - Preview
#Preview("Initial State (BT On)") {
	let viewModel = BLECentralViewModel()
	viewModel.canScan = true
	viewModel.message = "Ready to scan"

	return NavigationView {
		SensorPairingView()
			.environmentObject(viewModel) // Inject via environmentObject
	}
}

#Preview("Scanning") {
	let viewModel = BLECentralViewModel()
	viewModel.canScan = true
	viewModel.isScanning = true
	viewModel.message = "Searching for devices..."

	return NavigationView {
		 SensorPairingView()
			 .environmentObject(viewModel)
	}
}

#Preview("Connecting State") {
	let viewModel = BLECentralViewModel()
	viewModel.canScan = true
	viewModel.isConnecting = true // Set connecting flag
	viewModel.message = "Connecting to BonsaiPeripheral..."
	// Example device list shown *before* connecting starts
	viewModel.discoveredDevicesDisplay = ["★ BonsaiPeripheral (12AB34CD...)", "Other Device (FE98DCBA...)"]

	return NavigationView {
		SensorPairingView()
			.environmentObject(viewModel)
	}
}


#Preview("Devices Found") {
	let viewModel = BLECentralViewModel()
	viewModel.canScan = true
	viewModel.isScanning = false
	// Use the display list property
	viewModel.discoveredDevicesDisplay = ["★ BonsaiPeripheral (12AB34CD...)", "Living Room Sensor (56EF78AB...)", "Unknown Device (90CD12EF...)"]
	viewModel.message = "Found 3 devices. Select one to connect."

	return NavigationView {
		SensorPairingView()
			.environmentObject(viewModel)
	}
}

#Preview("No Devices Found") {
	let viewModel = BLECentralViewModel()
	viewModel.canScan = true
	viewModel.isScanning = false
	viewModel.discoveredDevicesDisplay = [] // Empty list
	viewModel.message = "Scan timed out. No devices found."

	return NavigationView {
		SensorPairingView()
			.environmentObject(viewModel)
	}
}

#Preview("Connected") {
	let viewModel = BLECentralViewModel()
	viewModel.canScan = true
	viewModel.isConnected = true // Is connected
	viewModel.isConnecting = false // No longer connecting
	viewModel.isScanning = false
	viewModel.message = "Device ready. Reading initial value..."
	viewModel.discoveredDevicesDisplay = ["★ BonsaiPeripheral (12AB34CD...)"] // Still show device list potentially

	return NavigationView {
		 SensorPairingView()
			 .environmentObject(viewModel)
	}
}

#Preview("Connection Failed") {
	let viewModel = BLECentralViewModel()
	viewModel.canScan = true
	viewModel.isConnected = false
	viewModel.isConnecting = false
	viewModel.isScanning = false
	viewModel.message = "Failed to connect to BonsaiPeripheral."
	viewModel.connectionError = "Required service not found."
	viewModel.discoveredDevicesDisplay = ["★ BonsaiPeripheral (12AB34CD...)", "Other Device (FE98DCBA...)"] // Show list for retry

	return NavigationView {
		 SensorPairingView()
			 .environmentObject(viewModel)
	}
}
