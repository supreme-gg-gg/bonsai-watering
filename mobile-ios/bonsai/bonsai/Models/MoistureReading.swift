//
//  MoistureReading.swift
//  bonsai
//
//  Created by Jet Chiang on 2025-03-15.
//

import Foundation
import SwiftData

@Model
final class MoistureReading {
	var timestamp: Date
	var moistureLevel: Double

	init(timestamp: Date = Date(), moistureLevel: Double) {
		self.timestamp = timestamp
		self.moistureLevel = moistureLevel
	}
}
