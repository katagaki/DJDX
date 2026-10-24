import SwiftUI
import UIKit

enum PolarisChordDifficulty: String, Codable, CaseIterable {
    case all = "Shared.All"
    case easy = "EASY"
    case normal = "NORMAL"
    case hard = "HARD"
    case influence = "INFLUENCE"
    case polar = "POLAR"
    case unknown = ""

    static let sorted: [PolarisChordDifficulty] = [
        .easy, .normal, .hard, .influence, .polar
    ]

    init(chartDifficultyType: Int) {
        switch chartDifficultyType {
        case 0: self = .easy
        case 1: self = .normal
        case 2: self = .hard
        case 3: self = .influence
        case 4: self = .polar
        default: self = .unknown
        }
    }

    var abbreviation: String {
        switch self {
        case .all: return "ALL"
        case .easy: return "ESY"
        case .normal: return "NOR"
        case .hard: return "HRD"
        case .influence: return "INF"
        case .polar: return "PLR"
        case .unknown: return ""
        }
    }

    var color: Color {
        switch self {
        case .easy: return .blue
        case .normal: return .green
        case .hard: return Color(UIColor { $0.userInterfaceStyle == .dark ? .systemYellow : .systemOrange })
        case .influence: return Color(red: 1.0, green: 0.35, blue: 0.7)
        case .polar: return Color(red: 0.0, green: 0.8, blue: 0.8)
        default: return .gray
        }
    }
}
