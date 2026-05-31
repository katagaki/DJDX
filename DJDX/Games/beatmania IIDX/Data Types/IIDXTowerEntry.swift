//
//  IIDXTowerEntry.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/02/20.
//

import Foundation
import SwiftData

@Model
final class IIDXTowerEntry: @unchecked Sendable {
    var playDate: Date = Date.distantPast
    var keyCount: Int = 0
    var scratchCount: Int = 0

    init(playDate: Date, keyCount: Int, scratchCount: Int) {
        self.playDate = playDate
        self.keyCount = keyCount
        self.scratchCount = scratchCount
    }
}
