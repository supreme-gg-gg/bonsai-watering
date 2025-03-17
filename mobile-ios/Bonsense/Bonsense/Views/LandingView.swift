//
//  LandingView.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-03-16.
//

import SwiftUI

struct LandingView: View {
	@StateObject private var viewModel = LandingViewModel()
	
	var body: some View {
		NavigationView {
			ZStack {
				BonsaiTheme.backgroundGradient
					.ignoresSafeArea()
				
				VStack(spacing: 40) {
					// Title with leaf icon
					VStack(spacing: 15) {
						Text("Bonsai")
							.font(BonsaiTheme.titleFont)
							.foregroundColor(BonsaiTheme.primaryGreen)
						
						Text("Water Monitor")
							.font(BonsaiTheme.headlineFont)
							.foregroundColor(BonsaiTheme.earthBrown)
					}
					
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
						Button(action: {
							viewModel.connectToSensor()
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
						
						NavigationLink(
							destination: PhotoView(),
							isActive: $viewModel.navigateToPhotoView
						) {
							Button(action: {
								viewModel.navigateToCamera()
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

#Preview {
	LandingView()
}
