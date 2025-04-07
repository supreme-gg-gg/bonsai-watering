//
//  BonsenseApp.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-03-16.
//

import SwiftUI

@main
struct BonsaiWaterMonitorApp: App {
	@StateObject private var bleViewModel = BLECentralViewModel()
	var body: some Scene {
		WindowGroup {
			LandingView()
				.environmentObject(bleViewModel)
		}
	}
}
