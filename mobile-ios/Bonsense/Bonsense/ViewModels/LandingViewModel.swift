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
	@Published var navigateToSensorView = false
	@Published var bluetoothViewModel = BLECentralViewModel()
		
	func connectToSensor() {
		bluetoothViewModel.startScanning()
		navigateToSensorView = true
	}
	
	func navigateToCamera() {
		navigateToPhotoView = true
	}
}
