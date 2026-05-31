//
//  SDVXDifficulty.swift
//  DJDX
//
//  Created by Claude on 2026/05/30.
//

import SwiftUI

// Maps to the 難易度 column in the SDVX CSV.
enum SDVXDifficulty: String, Codable, CaseIterable {
    case all = "Shared.All"
    case novice = "NOVICE"
    case advanced = "ADVANCED"
    case exhaust = "EXHAUST"
    case maximum = "MAXIMUM"
    // Infinite tier (the 5th slot, shown per song as one of these)
    case infinite = "INFINITE"
    case gravity = "GRAVITY"
    case heavenly = "HEAVENLY"
    case vivid = "VIVID"
    case exceed = "EXCEED"
    case ultimate = "ULTIMATE"
    case unknown = ""

    static let sorted: [SDVXDifficulty] = [
        .novice, .advanced, .exhaust, .maximum,
        .infinite, .gravity, .heavenly, .vivid, .exceed, .ultimate
    ]

    var abbreviation: String {
        switch self {
        case .all: return "ALL"
        case .novice: return "NOV"
        case .advanced: return "ADV"
        case .exhaust: return "EXH"
        case .maximum: return "MXM"
        case .infinite: return "INF"
        case .gravity: return "GRV"
        case .heavenly: return "HVN"
        case .vivid: return "VVD"
        case .exceed: return "XCD"
        case .ultimate: return "ULT"
        case .unknown: return ""
        }
    }

    // Whether this difficulty occupies the infinite-tier (5th) slot
    var isInfiniteTier: Bool {
        switch self {
        case .infinite, .gravity, .heavenly, .vivid, .exceed, .ultimate: return true
        default: return false
        }
    }

    var color: Color {
        switch self {
        case .novice: return .purple
        case .advanced: return .yellow
        case .exhaust: return .red
        case .maximum: return Color(white: 0.7)
        case .infinite: return .pink
        case .gravity: return .orange
        case .heavenly: return .cyan
        case .vivid: return Color(red: 1.0, green: 0.4, blue: 0.7)
        case .exceed: return .blue
        case .ultimate: return Color(white: 0.3)
        default: return .gray
        }
    }
}
