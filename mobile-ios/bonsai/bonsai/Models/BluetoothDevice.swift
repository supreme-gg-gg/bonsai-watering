//
//  BluetoothDevice.swift
//  bonsai
//
//  Created by Jet Chiang on 2025-03-15.
//

import Foundation
import SwiftData

@Model
final class BluetoothDevice {
	var deviceID: String
	var name: String

	init(deviceID: String, name: String) {
		self.deviceID = deviceID
		self.name = name
	}
}
