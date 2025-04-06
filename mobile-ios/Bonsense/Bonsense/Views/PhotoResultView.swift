//
//  PhotoResultView.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-04-06.
//

import SwiftUI

struct PhotoResultView: View {
	@ObservedObject var viewModel: ResultViewModel
	@Environment(\.presentationMode) var presentationMode

	var body: some View {
		ZStack {
			BonsaiTheme.backgroundGradient()
				.ignoresSafeArea()

			 ScrollView { // Allow scrolling
				VStack(spacing: 20) {

					// Header
					Text("Bonsai Moisture") // Simplified Title
						.font(BonsaiTheme.titleFont)
						.foregroundColor(BonsaiTheme.primaryGreen)
						.padding(.top, 30)

					// Classification Icon Display (Replaces Gauge)
					classificationIconView
						.padding(.vertical, 25) // More vertical padding

					// Bonsai status icons (Optional - might be redundant)
					// statusIconsView
					// .padding(.bottom, 10)

					// Recommendation card (Still relevant)
					recommendationCardView
						.padding(.horizontal)

					// Action Button (Only Disconnect)
					disconnectButtonView
						.padding(.vertical, 30) // More padding around single button

					 Spacer(minLength: 20)
				}
				.padding(.horizontal)
			}
		}
		.navigationBarBackButtonHidden(true)
		.navigationBarItems(leading: backButton)
	}

	// MARK: - Subviews

	private var classificationIconView: some View {
		ZStack {
			// Background Circle
			Circle()
				.fill(BonsaiTheme.sandBeige)
				.shadow(color: BonsaiTheme.earthBrown.opacity(0.15), radius: 8, y: 4)

			VStack(spacing: 10) {
				Image(systemName: classificationIconName)
					.font(.system(size: 75, weight: .light))
					.foregroundColor(waterLevelColor)
					.padding(.bottom, 5)

				Text(bandText)
					.font(BonsaiTheme.headlineFont.weight(.bold))
					.foregroundColor(waterLevelColor)
			}
			.padding()

		}
		.frame(width: 210, height: 210)
	}

	private var recommendationCardView: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("Recommendation")
				.font(BonsaiTheme.headlineFont)
				.foregroundColor(BonsaiTheme.earthBrown)
				.padding(.bottom, 5)

			HStack(alignment: .top, spacing: 15) {
				recommendationIcon // Uses the same logic based on band
					.font(.system(size: 32))
					.foregroundColor(waterLevelColor)
					.frame(width: 35, alignment: .center)

				Text(viewModel.waterLevel.message) // Uses the same message
					.font(BonsaiTheme.bodyFont)
					.foregroundColor(BonsaiTheme.earthBrown.opacity(0.9))
					.lineSpacing(4)
					.fixedSize(horizontal: false, vertical: true)

				Spacer()
			}
		}
		.padding()
		.background(BonsaiTheme.sandBeige.opacity(0.8))
		.cornerRadius(18)
		.shadow(color: BonsaiTheme.earthBrown.opacity(0.1), radius: 4, x: 0, y: 2)
	}

	private var disconnectButtonView: some View {
		Button(action: {
			presentationMode.wrappedValue.dismiss()
		}) {
			HStack {
				Image(systemName: "house")
				Text("Home")
			}
			 .font(BonsaiTheme.bodyFont.weight(.medium))
			 .padding(.vertical, 12)
			 .padding(.horizontal, 25) // More horizontal padding for single button
			 .frame(maxWidth: 250) // Max width for the button
			 .background(BonsaiTheme.lightGreen)
			 .foregroundColor(BonsaiTheme.primaryGreen)
			 .cornerRadius(12)
			 .shadow(color: BonsaiTheme.lightGreen.opacity(0.4), radius: 3, y: 2)
		}
		 .buttonStyle(PlainButtonStyle())
	}

	// Back button (Identical to ResultView's)
	private var backButton: some View {
		 Button(action: {
			 presentationMode.wrappedValue.dismiss()
		 }) {
			 HStack {
				 Image(systemName: "chevron.left")
				 Text("Back")
			 }
			 .foregroundColor(BonsaiTheme.primaryGreen)
		 }
	}


	// MARK: - Computed Properties for Display Logic

	private var waterLevelColor: Color {
		BonsaiTheme.waterLevelColor(viewModel.waterLevel.band)
	}

	// Main classification icon name
	private var classificationIconName: String {
		 switch viewModel.waterLevel.band {
		 case .low: return "sun.max.fill" // Represents dryness
		 case .humid: return "humidity.fill" // Represents optimal humidity
		 case .wet: return "drop.fill" // Represents wetness
		 }
	}

	// Text description (similar to ResultView but maybe tweaked)
	private var bandText: String {
		switch viewModel.waterLevel.band {
		case .low: return "Soil is Dry"
		case .humid: return "Soil is Humid"
		case .wet: return "Soil is Wet"
		}
	}

	// Icon for the recommendation card (Identical to ResultView's)
	private var recommendationIcon: Image {
		switch viewModel.waterLevel.band {
		case .low: return Image(systemName: "exclamationmark.bubble.fill")
		case .humid: return Image(systemName: "checkmark.circle.fill")
		case .wet: return Image(systemName: "nosign.app.fill")
		}
	}
}

#Preview("Dry") {
	PhotoResultView(viewModel: ResultViewModel(waterLevel: WaterLevel(percentage: 25.0)))
}

#Preview("Humid") {
	PhotoResultView(viewModel: ResultViewModel(waterLevel: WaterLevel(percentage: 55.0)))
}

#Preview("Wet") {
	PhotoResultView(viewModel: ResultViewModel(waterLevel: WaterLevel(percentage: 85.0)))
}
