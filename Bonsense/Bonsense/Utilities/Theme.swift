//
//  Theme.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-03-16.
//

import Foundation
import SwiftUI

struct BonsaiTheme {
	// Color palette
	static let primaryGreen = Color("PrimaryGreen") // A deep, rich green (#2D6A4F)
	static let lightGreen = Color("LightGreen")     // A softer green (#74C69D)
	static let earthBrown = Color("EarthBrown")     // A warm brown (#815839)
	static let sandBeige = Color("SandBeige")       // A light beige (#F4EBD0)
	static let skyBlue = Color("SkyBlue")           // A soft blue (#A8DADC)
	
	// Custom fonts
	static let titleFont = Font.custom("Avenir-Heavy", size: 28)
	static let headlineFont = Font.custom("Avenir-Medium", size: 20)
	static let bodyFont = Font.custom("Avenir", size: 16)
	
	// Water level colors
	static func waterLevelColor(_ band: WaterLevel.WaterBand) -> Color {
		switch band {
		case .low:
			return Color.red.opacity(0.8)
		case .humid:
			return skyBlue
		case .wet:
			return primaryGreen
		}
	}
	
	// Backgrounds
	static func backgroundGradient() -> LinearGradient {
		return LinearGradient(
			gradient: Gradient(colors: [sandBeige.opacity(0.5), primaryGreen.opacity(0.3)]),
			startPoint: .top,
			endPoint: .bottom
		)
	}
}
