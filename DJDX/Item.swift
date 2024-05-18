//
//  Item.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/18.
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
