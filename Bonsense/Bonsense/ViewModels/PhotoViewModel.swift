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
    @Published var errorMessage: String?
	private var predictionService: SVCPredictionService?
	
	init() {
		do {
			predictionService = try SVCPredictionService()
		} catch {
			print("Failure to initalize prediction service: \(error)")
		}
	}
    
    func processImage() {
        guard let image = capturedImage else {
            errorMessage = "No image captured"
            return
        }
        guard let predictionService = predictionService else {
            errorMessage = "Prediction service not available"
            return
        }
        
        // Run prediction in background
        Task { @MainActor in
            do {
                let label = try await Task.detached(priority: .userInitiated) {
                    try predictionService.predict(image: image)
                }.value
				
				waterLevel = WaterLevel(label: label.lowercased())
                navigateToResult = true
                
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

