import SwiftUI

enum PopnDifficulty: String, Codable, CaseIterable {
    case all = "Shared.All"
    case easy = "EASY"
    case normal = "NORMAL"
    case hyper = "HYPER"
    case extra = "EX"
    case unknown = ""

    static let sorted: [PopnDifficulty] = [.easy, .normal, .hyper, .extra]

    init(label: String) {
        switch label.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "EASY", "LIGHT": self = .easy
        case "NORMAL": self = .normal
        case "HYPER": self = .hyper
        case "EX": self = .extra
        default: self = .unknown
        }
    }

    var abbreviation: String {
        switch self {
        case .all: return "ALL"
        case .easy: return "E"
        case .normal: return "N"
        case .hyper: return "H"
        case .extra: return "EX"
        case .unknown: return ""
        }
    }

    var color: Color {
        switch self {
        case .easy: return .blue
        case .normal: return .green
        case .hyper: return .orange
        case .extra: return .red
        default: return .gray
        }
    }
}
