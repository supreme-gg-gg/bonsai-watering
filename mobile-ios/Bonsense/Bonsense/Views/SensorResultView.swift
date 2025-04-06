//
//  ResultView.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-03-16.
//

import SwiftUI

struct SensorResultView: View {
	@ObservedObject var viewModel: ResultViewModel
	@Environment(\.presentationMode) var presentationMode
	@EnvironmentObject var bluetoothViewModel: BLECentralViewModel // Keep using EnvironmentObject if set up

	var body: some View {
		ZStack {
			BonsaiTheme.backgroundGradient()
				.ignoresSafeArea()

			ScrollView { // Allow scrolling on smaller devices
				VStack(spacing: 20) { // Adjusted main spacing

					// Header
					Text("Bonsai Health Report")
						.font(BonsaiTheme.titleFont)
						.foregroundColor(BonsaiTheme.primaryGreen)
						.padding(.top, 30) // Add padding from top

					// Water level display (Gauge)
					gaugeView
						.padding(.vertical, 15)

					// Bonsai status icons
					statusIconsView
						.padding(.bottom, 10)

					// Recommendation card
					recommendationCardView
						.padding(.horizontal) // Add horizontal padding to card container

					// Action Buttons - Now in an HStack
					actionButtonsView
						.padding(.vertical, 20) // Add padding around buttons

					Spacer(minLength: 20) // Ensure some space at the bottom
				}
				.padding(.horizontal) // Overall horizontal padding for content
			}
		}
		.navigationBarBackButtonHidden(true)
		.navigationBarItems(leading: backButton) // Use custom back button
	}

	// MARK: - Subviews

	private var gaugeView: some View {
		ZStack {
			// Background track
			Circle()
				.stroke(BonsaiTheme.sandBeige, lineWidth: 22) // Slightly thicker, theme color

			// Foreground progress
			Circle()
				.trim(from: 0, to: CGFloat(viewModel.waterLevel.percentage) / 100)
				.stroke(waterLevelColor, style: StrokeStyle(lineWidth: 22, lineCap: .round)) // Match thickness
				.rotationEffect(.degrees(-90))
				.animation(.easeInOut(duration: 0.8), value: viewModel.waterLevel.percentage)

			// Text inside gauge
			VStack(spacing: 2) {
				Text("\(Int(viewModel.waterLevel.percentage))%")
					.font(.system(size: 45, weight: .bold, design: .rounded)) // Slightly smaller font
					.foregroundColor(waterLevelColor)
					.animation(nil, value: viewModel.waterLevel.percentage) // Don't animate text itself

				Text(bandText)
					.font(BonsaiTheme.headlineFont)
					.foregroundColor(waterLevelColor.opacity(0.8)) // Slightly muted text color
			}
		}
		.frame(width: 210, height: 210) // Slightly larger frame
	}

	private var statusIconsView: some View {
		HStack(spacing: 45) { // Increased spacing
			VStack(spacing: 5) {
				Image(systemName: "drop.fill")
					.font(.system(size: 28)) // Slightly smaller icon
					.foregroundColor(waterLevelColor)
				Text("Moisture")
					.font(BonsaiTheme.bodyFont)
					.foregroundColor(BonsaiTheme.earthBrown)
			}

			VStack(spacing: 5) {
				Image(systemName: "leaf.fill") // Could be dynamic based on overall health later
					.font(.system(size: 28))
					.foregroundColor(BonsaiTheme.primaryGreen)
				Text("Plant") // More generic term?
					.font(BonsaiTheme.bodyFont)
					.foregroundColor(BonsaiTheme.earthBrown)
			}
		}
	}

	private var recommendationCardView: some View {
		VStack(alignment: .leading, spacing: 10) { // Align content left
			Text("Recommendation")
				.font(BonsaiTheme.headlineFont)
				.foregroundColor(BonsaiTheme.earthBrown)
				.padding(.bottom, 5) // Space below title

			HStack(alignment: .top, spacing: 15) { // Align icon top
				recommendationIcon
					.font(.system(size: 32)) // Slightly smaller icon
					.foregroundColor(waterLevelColor)
					.frame(width: 35, alignment: .center) // Give icon fixed width

				Text(viewModel.waterLevel.message)
					.font(BonsaiTheme.bodyFont)
					.foregroundColor(BonsaiTheme.earthBrown.opacity(0.9))
					.lineSpacing(4) // Add line spacing for readability
					.fixedSize(horizontal: false, vertical: true) // Allow text wrapping

				Spacer() // Push content left
			}
		}
		.padding() // Padding inside the card
		.background(BonsaiTheme.sandBeige.opacity(0.8)) // Card background
		.cornerRadius(18) // Slightly rounder corners
		.shadow(color: BonsaiTheme.earthBrown.opacity(0.1), radius: 4, x: 0, y: 2) // Softer shadow
	}

	private var actionButtonsView: some View {
		HStack(spacing: 20) { // Buttons side-by-side
			// Refresh Button
			Button(action: {
				// Add subtle animation/feedback on tap?
				bluetoothViewModel.refreshMoistureValue()
			}) {
				HStack {
					Image(systemName: "arrow.clockwise")
					Text("Refresh")
				}
				.font(BonsaiTheme.bodyFont.weight(.medium)) // Medium weight
				.padding(.vertical, 12)
				.padding(.horizontal, 20)
				.frame(maxWidth: .infinity) // Allow button to grow
				.background(BonsaiTheme.earthBrown)
				.foregroundColor(.white)
				.cornerRadius(12) // Consistent corner radius
				.shadow(color: BonsaiTheme.earthBrown.opacity(0.3), radius: 3, y: 2)
			}
			.buttonStyle(PlainButtonStyle()) // Remove default button effects if needed

			// Disconnect Button
			Button(action: {
				bluetoothViewModel.disconnect()
				presentationMode.wrappedValue.dismiss()
			}) {
				HStack {
					Image(systemName: "house") // Simpler icon
					Text("Disconnect")
				}
				 .font(BonsaiTheme.bodyFont.weight(.medium))
				 .padding(.vertical, 12)
				 .padding(.horizontal, 20)
				 .frame(maxWidth: .infinity)
				 .background(BonsaiTheme.lightGreen)
				 .foregroundColor(BonsaiTheme.primaryGreen) // Darker text on light green
				 .cornerRadius(12)
				 .shadow(color: BonsaiTheme.lightGreen.opacity(0.4), radius: 3, y: 2)
			}
			 .buttonStyle(PlainButtonStyle())
		}
	}

	private var backButton: some View {
		 Button(action: {
			 presentationMode.wrappedValue.dismiss()
		 }) {
			 HStack {
				 Image(systemName: "chevron.left")
				 Text("Back")
			 }
			 .foregroundColor(BonsaiTheme.primaryGreen) // Theme color
		 }
	}


	// MARK: - Computed Properties for Display Logic

	private var waterLevelColor: Color {
		BonsaiTheme.waterLevelColor(viewModel.waterLevel.band)
	}

	private var bandText: String {
		switch viewModel.waterLevel.band {
		case .low: return "Low Water"
		case .humid: return "Optimal" // Shorter text
		case .wet: return "Too Wet" // Clearer text
		}
	}

	private var recommendationIcon: Image { // Return Image directly
		switch viewModel.waterLevel.band {
		case .low: return Image(systemName: "exclamationmark.bubble.fill") // Softer warning
		case .humid: return Image(systemName: "checkmark.circle.fill")
		case .wet: return Image(systemName: "nosign.app.fill") // "Stop" sign like icon
		}
	}
}

// MARK: - Previews

// Make sure previews provide the EnvironmentObject if needed
#Preview("Low Water") {
	SensorResultView(viewModel: ResultViewModel(waterLevel: WaterLevel(percentage: 25.0)))
		.environmentObject(BLECentralViewModel()) // Add dummy BLE VM for preview
}

#Preview("Humid") {
	SensorResultView(viewModel: ResultViewModel(waterLevel: WaterLevel(percentage: 55.0)))
		 .environmentObject(BLECentralViewModel())
}

#Preview("Wet") {
	SensorResultView(viewModel: ResultViewModel(waterLevel: WaterLevel(percentage: 85.0)))
		 .environmentObject(BLECentralViewModel())
}
