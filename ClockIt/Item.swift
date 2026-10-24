//
//  Item.swift
//  ClockIt
//
//  Created by Wesley Harden on 10/24/26.
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
