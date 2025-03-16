//
//  Item.swift
//  bonsai
//
//  Created by Jet Chiang on 2025-03-15.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
