//
//  SensorReadingView.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-03-17.
//

import SwiftUI

struct SensorReadingView: View {
	@ObservedObject var bluetoothViewModel: BluetoothViewModel
	@Environment(\.presentationMode) var presentationMode
	
	var body: some View {
		ZStack {
			BonsaiTheme.backgroundGradient()
				.ignoresSafeArea()
			
			VStack(spacing: 25) {
				Text("Sensor Connection")
					.font(BonsaiTheme.titleFont)
					.foregroundColor(BonsaiTheme.primaryGreen)
				
				if bluetoothViewModel.isAdvertising {
					// Display connecting animation
					VStack(spacing: 20) {
						ZStack {
							Circle()
								.fill(BonsaiTheme.sandBeige)
								.frame(width: 200, height: 200)
								.shadow(color: BonsaiTheme.earthBrown.opacity(0.3), radius: 10)
							
							if bluetoothViewModel.isConnected {
								Image(systemName: "checkmark.circle.fill")
									.resizable()
									.scaledToFit()
									.foregroundColor(BonsaiTheme.primaryGreen)
									.frame(width: 100, height: 100)
							} else {
								ProgressView()
									.scaleEffect(2)
									.progressViewStyle(CircularProgressViewStyle(tint: BonsaiTheme.primaryGreen))
							}
						}
						
						Text(bluetoothViewModel.isConnected ? "Connected" : "Searching for device...")
							.font(BonsaiTheme.headlineFont)
							.foregroundColor(BonsaiTheme.earthBrown)
					}
				} else {
					Text("Bluetooth not active")
						.font(BonsaiTheme.headlineFont)
						.foregroundColor(.red)
				}
				
				// Status card
				VStack(spacing: 15) {
					Text("Connection Status")
						.font(BonsaiTheme.headlineFont)
						.foregroundColor(BonsaiTheme.earthBrown)
					
					HStack {
						Image(systemName: bluetoothViewModel.isConnected ? "antenna.radiowaves.left.and.right.circle.fill" : "antenna.radiowaves.left.and.right.slash")
							.font(.system(size: 30))
							.foregroundColor(bluetoothViewModel.isConnected ? BonsaiTheme.primaryGreen : .red)
						
						VStack(alignment: .leading) {
							Text(bluetoothViewModel.isConnected ? "Device Connected" : "Waiting for Connection")
								.font(BonsaiTheme.bodyFont.bold())
							
							Text(bluetoothViewModel.message)
								.font(BonsaiTheme.bodyFont)
								.foregroundColor(.secondary)
						}
					}
					.padding()
					.frame(maxWidth: .infinity, alignment: .leading)
					.background(BonsaiTheme.sandBeige.opacity(0.5))
					.cornerRadius(12)
				}
				.padding()
				.background(Color.white.opacity(0.7))
				.cornerRadius(20)
				.shadow(color: Color.gray.opacity(0.2), radius: 5)
				
				Spacer()
				
				// Back button
				Button(action: {
					presentationMode.wrappedValue.dismiss()
				}) {
					HStack {
						Image(systemName: "arrow.left")
						Text("Back to Home")
					}
					.font(BonsaiTheme.bodyFont)
					.padding()
					.frame(width: 200)
					.background(BonsaiTheme.lightGreen)
					.foregroundColor(.white)
					.cornerRadius(15)
					.shadow(radius: 3)
				}
				.padding(.bottom, 20)
				
				// Navigation link to Results
				NavigationLink(
					destination: ResultView(viewModel: ResultViewModel(waterLevel: bluetoothViewModel.waterLevel ?? WaterLevel(percentage: 0))).environmentObject(bluetoothViewModel),
					isActive: $bluetoothViewModel.navigateToResult
				) {
					EmptyView()
				}
			}
			.padding()
		}
		.navigationBarBackButtonHidden(true)
		.navigationBarItems(leading:
			Button(action: {
				presentationMode.wrappedValue.dismiss()
			}) {
				HStack {
					Image(systemName: "chevron.left")
					Text("Back")
				}
				.foregroundColor(BonsaiTheme.primaryGreen)
			}
		)
	}
}

#Preview("Connecting") {
	let viewModel = BluetoothViewModel()
	viewModel.isAdvertising = true
	viewModel.message = "Searching for Raspberry Pi..."
	
	return SensorReadingView(bluetoothViewModel: viewModel)
}

#Preview("Connected") {
	let viewModel = BluetoothViewModel()
	viewModel.isAdvertising = true
	viewModel.isConnected = true
	viewModel.message = "Connected to Bonsai Sensor"
	
	return SensorReadingView(bluetoothViewModel: viewModel)
}
