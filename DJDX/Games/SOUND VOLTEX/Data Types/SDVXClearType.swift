import SwiftUI

// Maps to the クリアランク column in the SDVX CSV.
enum SDVXClearType: String, Codable {
    case all = "Shared.All"
    case played = "PLAYED"
    case complete = "COMPLETE"
    case excessive = "EXCESSIVE COMPLETE"
    case ultimateChain = "ULTIMATE CHAIN"
    case perfectUltimateChain = "PERFECT ULTIMATE CHAIN"
    case noPlay = "NO PLAY"
    case unknown = ""

    static let sorted: [SDVXClearType] = [
        .perfectUltimateChain,
        .ultimateChain,
        .excessive,
        .complete,
        .played,
        .noPlay
    ]

    static let sortedWithoutNoPlay: [SDVXClearType] = [
        .perfectUltimateChain,
        .ultimateChain,
        .excessive,
        .complete,
        .played
    ]

    static var sortedStrings: [String] {
        sorted.map { $0.rawValue }
    }

    static var sortedStringsWithoutNoPlay: [String] {
        sortedWithoutNoPlay.map { $0.rawValue }
    }

    var abbreviation: String {
        switch self {
        case .all: return "ALL"
        case .played: return "PLAY"
        case .complete: return "COMP"
        case .excessive: return "EXC"
        case .ultimateChain: return "UC"
        case .perfectUltimateChain: return "PUC"
        case .noPlay: return "NP"
        case .unknown: return ""
        }
    }

    var color: Color {
        switch self {
        case .perfectUltimateChain: return .yellow
        case .ultimateChain: return .cyan
        case .excessive: return .red
        case .complete: return .green
        case .played: return .gray
        default: return .secondary
        }
    }
}
