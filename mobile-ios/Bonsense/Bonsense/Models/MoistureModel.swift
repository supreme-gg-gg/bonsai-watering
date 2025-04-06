//
//  MoistureModel.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-03-16.
//

import Foundation

struct WaterLevel {
	let percentage: Double
	
	var band: WaterBand {
		switch percentage {
			case 0..<40:
				return .low
			case 40..<70:
				return .humid
			default:
				return .wet
		}
	}
	
	var shouldWater: Bool {
		return band == .low
	}
	
	var message: String {
		switch band {
		case .low:
			return "Your bonsai soil is dry. Time for a drink!"
		case .humid:
			return "Soil moisture is optimal. Your bonsai looks happy!"
		case .wet:
			return "Soil is quite wet. Ensure good drainage."
		}
	}
	
	enum WaterBand {
		case low, humid, wet
	}
}
