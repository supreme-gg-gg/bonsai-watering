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
			return "Your bonsai needs water! Please water it soon."
		case .humid:
			return "Your bonsai has ideal moisture. No need to water yet."
		case .wet:
			return "Your bonsai is well watered. Check again in a few days."
		}
	}
	
	enum WaterBand {
		case low, humid, wet
	}
}
