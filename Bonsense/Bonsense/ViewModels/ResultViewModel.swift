//
//  ResultViewModel.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-03-16.
//

import Foundation
import SwiftUI

class ResultViewModel: ObservableObject {
	@Published var waterLevel: WaterLevel
	
	init(waterLevel: WaterLevel) {
		self.waterLevel = waterLevel
	}
	
	var bandColor: Color {
		switch waterLevel.band {
			case .low:
				return .red
			case .humid:
				return .blue
			case .wet:
				return .green
			case .none:
				return .black
		}
	}
}
