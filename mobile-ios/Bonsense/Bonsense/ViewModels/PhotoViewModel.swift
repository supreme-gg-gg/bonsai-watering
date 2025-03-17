//
//  PhotoViewModel.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-03-16.
//

import Foundation
import SwiftUI

class PhotoViewModel: ObservableObject {
	@Published var capturedImage: UIImage?
	@Published var navigateToResult = false
	@Published var waterLevel: WaterLevel?
	
	// In a real app, this would process the image using ML model
	func processImage() {
		// Simulating ML model with random value
		let randomPercentage = Double.random(in: 0...100)
		waterLevel = WaterLevel(percentage: randomPercentage)
		navigateToResult = true
	}
}
