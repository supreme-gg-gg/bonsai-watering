//
//  LandingView.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-03-16.
//

import SwiftUI

struct LandingView: View {
	@State private var navigateToPhoto = false
	@State private var navigateToSensor = false
	
	var body: some View {
		NavigationView {
			ZStack {
				BonsaiTheme.backgroundGradient()
					.ignoresSafeArea()
				
				VStack(spacing: 40) {
					Spacer()
					// Title with leaf icon
					VStack(spacing: 8) {
						Text("BonSense") // Updated Title
							.font(BonsaiTheme.titleFont)
							.foregroundColor(BonsaiTheme.primaryGreen)

						// Optional: Keep divider or remove if subtitle is enough
						 Rectangle()
						     .frame(height: 1)
						     .foregroundColor(BonsaiTheme.lightGreen.opacity(0.5))
						     .frame(width: 100)

						Text("Listen to Your Leaves.") // Updated Subtitle
							.font(BonsaiTheme.headlineFont)
							.foregroundColor(BonsaiTheme.earthBrown.opacity(0.8))
					}
					.padding(.bottom, 30)
					
					// Bonsai image
					ZStack {
						Circle()
							.fill(BonsaiTheme.sandBeige)
							.frame(width: 200, height: 200)
						
						Image(systemName: "leaf.fill")
							.resizable()
							.scaledToFit()
							.frame(width: 100, height: 100)
							.foregroundColor(BonsaiTheme.primaryGreen)
					}
					.shadow(color: BonsaiTheme.earthBrown.opacity(0.3), radius: 10)
					
					Spacer()
					
					// Action buttons
					VStack(spacing: 20) {
						
						
						NavigationLink(
							destination: PhotoView(),
							isActive: $navigateToPhoto
						) {
							Button(action: {
								navigateToPhoto = true
							}) {
								HStack {
									Image(systemName: "camera.fill")
										.font(.system(size: 20))
									
									Text("Take a Photo")
										.font(BonsaiTheme.bodyFont)
								}
								.padding()
								.frame(maxWidth: .infinity)
								.background(BonsaiTheme.primaryGreen)
								.foregroundColor(.white)
								.cornerRadius(15)
								.shadow(radius: 3)
							}
							.padding(.horizontal)
						}
						
						NavigationLink(
							destination: SensorPairingView(),
							isActive: $navigateToSensor
						) {
							Button(action: {
								navigateToSensor = true
							}) {
								HStack {
									Image(systemName: "antenna.radiowaves.left.and.right")
										.font(.system(size: 20))
									
									Text("Connect to Sensor")
										.font(BonsaiTheme.bodyFont)
								}
								.padding()
								.frame(maxWidth: .infinity)
								.background(BonsaiTheme.skyBlue)
								.foregroundColor(.white)
								.cornerRadius(15)
								.shadow(radius: 3)
							}
							.padding(.horizontal)
						}
					}
					
					// Decorative elements
					HStack(spacing: 30) {
						Image(systemName: "drop.fill")
							.foregroundColor(BonsaiTheme.skyBlue)
						
						Image(systemName: "leaf.fill")
							.foregroundColor(BonsaiTheme.lightGreen)
						
						Image(systemName: "sun.max.fill")
							.foregroundColor(Color.yellow)
					}
					.font(.system(size: 22))
					.padding(.bottom, 20)
				}
				.padding(.vertical, 40)
			}
		}
	}
}

#Preview() {
	LandingView()
}
