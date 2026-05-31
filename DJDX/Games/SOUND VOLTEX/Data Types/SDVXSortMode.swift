//
//  SDVXSortMode.swift
//  DJDX
//
//  Created by Claude on 2026/05/30.
//

import Foundation

enum SDVXSortMode: String, CaseIterable, Codable {
    case title = "Shared.Sort.Title"
    case clearType = "Shared.SDVX.ClearType"
    case score = "Shared.Sort.Score"
    case level = "Shared.Sort.Difficulty"
}
