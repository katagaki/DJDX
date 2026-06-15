import SwiftUI
import UIKit

// Maps to the 難易度 column in the SDVX CSV.
enum SDVXDifficulty: String, Codable, CaseIterable {
    case all = "Shared.All"
    case novice = "NOVICE"
    case advanced = "ADVANCED"
    case exhaust = "EXHAUST"
    case infinite = "INFINITE"
    case maximum = "MAXIMUM"
    case gravity = "GRAVITY"
    case heavenly = "HEAVENLY"
    case vivid = "VIVID"
    case exceed = "EXCEED"
    case nabla = "NABLA"
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
        case .infinite: return "INF"
        case .maximum: return "MXM"
        case .gravity: return "GRV"
        case .heavenly: return "HVN"
        case .vivid: return "VVD"
        case .exceed: return "XCD"
        case .nabla: return "NBL"
        case .ultimate: return "ULT"
        case .unknown: return ""
        }
    }

    var sdvxInSlot: String {
        switch self {
        case .novice: return "n"
        case .advanced: return "a"
        case .exhaust: return "e"
        default: return "m"
        }
    }

    // Whether this difficulty occupies the infinite-tier (5th) slot
    var isInfiniteTier: Bool {
        switch self {
        case .infinite, .gravity, .heavenly, .vivid, .exceed, .nabla, .ultimate: return true
        default: return false
        }
    }

    var color: Color {
        switch self {
        case .novice: return .purple
        case .advanced: return Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.78, green: 0.58, blue: 0.0, alpha: 1.0) : .systemYellow })
        case .exhaust: return .red
        case .infinite: return .pink
        case .maximum: return Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(white: 0.4, alpha: 1.0) : UIColor(white: 0.7, alpha: 1.0) })
        case .gravity: return .orange
        case .heavenly: return .cyan
        case .vivid: return Color(red: 1.0, green: 0.4, blue: 0.7)
        case .exceed: return .blue
        case .nabla: return .green
        case .ultimate: return Color(white: 0.3)
        default: return .gray
        }
    }
}
