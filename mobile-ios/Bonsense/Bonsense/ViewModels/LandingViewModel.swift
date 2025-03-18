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
	@Published var bluetoothViewModel = BluetoothViewModel()
		
	func connectToSensor() {
		bluetoothViewModel.startAdvertising()
		navigateToSensorView = true
	}
	
	func navigateToCamera() {
		navigateToPhotoView = true
	}
}
