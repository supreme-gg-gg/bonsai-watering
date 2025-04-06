//
//  ResultView.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-03-16.
//

import SwiftUI

struct ResultView: View {
	@ObservedObject var viewModel: ResultViewModel
	@Environment(\.presentationMode) var presentationMode
	@EnvironmentObject var bluetoothViewModel: BLECentralViewModel
	
	var body: some View {
		ZStack {
			BonsaiTheme.backgroundGradient()
				.ignoresSafeArea()
			
			VStack(spacing: 25) {
				
				Spacer()
				// Header
				Text("Bonsai Health Report")
					.font(BonsaiTheme.titleFont)
					.foregroundColor(BonsaiTheme.primaryGreen)
				
				// Water level display
				ZStack {
					Circle()
						.stroke(Color.gray.opacity(0.3), lineWidth: 20)
						.frame(width: 200, height: 200)
					
					Circle()
						.trim(from: 0, to: CGFloat(viewModel.waterLevel.percentage) / 100)
						.stroke(waterLevelColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
						.frame(width: 200, height: 200)
						.rotationEffect(.degrees(-90))
						.animation(.easeInOut, value: viewModel.waterLevel.percentage)
					
					VStack {
						Text("\(Int(viewModel.waterLevel.percentage))%")
							.font(.system(size: 48, weight: .bold, design: .rounded))
							.foregroundColor(waterLevelColor)
						
						Text(bandText)
							.font(BonsaiTheme.headlineFont)
							.foregroundColor(waterLevelColor)
					}
				}
				.padding(.vertical, 20)
				
				// Bonsai status icons
				HStack(spacing: 30) {
					VStack {
						Image(systemName: "drop.fill")
							.font(.system(size: 30))
							.foregroundColor(waterLevelColor)
						Text("Moisture")
							.font(BonsaiTheme.bodyFont)
							.foregroundColor(BonsaiTheme.earthBrown)
					}
					
					VStack {
						Image(systemName: "leaf.fill")
							.font(.system(size: 30))
							.foregroundColor(BonsaiTheme.primaryGreen)
						Text("Health")
							.font(BonsaiTheme.bodyFont)
							.foregroundColor(BonsaiTheme.earthBrown)
					}
				}
				.padding()
				
				// Recommendation card
				VStack(spacing: 15) {
					Text("Recommendation")
						.font(BonsaiTheme.headlineFont)
						.foregroundColor(BonsaiTheme.earthBrown)
					
					HStack(spacing: 15) {
						recommendationIcon
							.font(.system(size: 36))
							.foregroundColor(waterLevelColor)
						
						Text(viewModel.waterLevel.message)
							.font(BonsaiTheme.bodyFont)
							.foregroundColor(BonsaiTheme.earthBrown)
							.fixedSize(horizontal: false, vertical: true)
					}
					.padding()
					.background(waterLevelColor.opacity(0.1))
					.cornerRadius(15)
				}
				.padding()
				.background(BonsaiTheme.sandBeige.opacity(0.7))
				.cornerRadius(20)
				.shadow(color: Color.gray.opacity(0.3), radius: 5)
				
				Button(action: {
					bluetoothViewModel.refreshMoistureValue()
				}) {
					HStack {
						Image(systemName: "arrow.clockwise.circle.fill")
						Text("Refresh")
					}
					.font(BonsaiTheme.bodyFont)
					.padding()
					.frame(width: 200)
					.background(BonsaiTheme.earthBrown)
					.foregroundColor(.white)
					.cornerRadius(15)
					.shadow(radius: 3)
				}
				
				// Back to home button
				Button(action: {
					bluetoothViewModel.disconnect() // Disconnect Bluetooth
					presentationMode.wrappedValue.dismiss() // Go back to Home
				}) {
					HStack {
						Image(systemName: "house.fill")
						Text("Disconnect")
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
	
	var waterLevelColor: Color {
		BonsaiTheme.waterLevelColor(viewModel.waterLevel.band)
	}
	
	var bandText: String {
		switch viewModel.waterLevel.band {
		case .low:
			return "Low Water"
		case .humid:
			return "Humid"
		case .wet:
			return "Wet"
		}
	}
	
	var recommendationIcon: some View {
		Group {
			switch viewModel.waterLevel.band {
			case .low:
				Image(systemName: "exclamationmark.triangle.fill")
			case .humid:
				Image(systemName: "checkmark.circle.fill")
			case .wet:
				Image(systemName: "hand.raised.fill")
			}
		}
	}
}

// Add previews for each water level band
#Preview("Low Water") {
	ResultView(viewModel: ResultViewModel(waterLevel: WaterLevel(percentage: 25.0)))
}

#Preview("Humid") {
	ResultView(viewModel: ResultViewModel(waterLevel: WaterLevel(percentage: 55.0)))
}

#Preview("Wet") {
	ResultView(viewModel: ResultViewModel(waterLevel: WaterLevel(percentage: 85.0)))
}
