//
//  LandingViewModel.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-03-16.
//

import Foundation
import SwiftUI

class LandingViewModel: ObservableObject {
	@Published var navigateToPhotoView = false
	
	func connectToSensor() {
		// This will be implemented in the future
		print("Connect to sensor button pressed - functionality to be implemented")
	}
	
	func navigateToCamera() {
		navigateToPhotoView = true
	}
}
