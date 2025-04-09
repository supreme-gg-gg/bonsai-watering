//
//  MoistureModel.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-03-16.
//

import Foundation

struct WaterLevel {
	
	enum WaterBand {
		case low, humid, wet
	}
	
    let percentage: Double?
	var band: WaterBand!
    
	// Initializer for percentage
	init(percentage: Double) {
		self.percentage = percentage
		switch percentage {
			case 0..<40:
				self.band = .low
			case 40..<70:
				self.band = .humid
			default:
				self.band = .wet
		}
	}
    
	// Initializer for label
    init(label: String) {
		self.percentage = nil
        switch label.lowercased() {
			case "wet":
				self.band = .wet
			case "moist":
				self.band = .humid
			case "dry":
				self.band = .low
			default:
				self.band = .low
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
			default:
				return "Unknown"
		}
	}
	
	
}
