import SwiftUI

enum GITADORAClearType: String, Codable {
    case all = "Shared.All"
    case excellent = "EXCELLENT"
    case fullCombo = "FULL COMBO"
    case clear = "CLEAR"
    case failed = "FAILED"
    case noPlay = "NO PLAY"
    case unknown = ""

    static let sorted: [GITADORAClearType] = [.excellent, .fullCombo, .clear, .failed, .noPlay]

    static let sortedWithoutNoPlay: [GITADORAClearType] = [.excellent, .fullCombo, .clear, .failed]

    static var sortedStringsWithoutNoPlay: [String] {
        sortedWithoutNoPlay.map { $0.rawValue }
    }

    var abbreviation: String {
        switch self {
        case .all: "ALL"
        case .excellent: "EXC"
        case .fullCombo: "FC"
        case .clear: "CLEAR"
        case .failed: "FAIL"
        case .noPlay: "NP"
        case .unknown: ""
        }
    }

    var color: Color {
        switch self {
        case .excellent: .yellow
        case .fullCombo: .cyan
        case .clear: .green
        case .failed: .red
        case .noPlay: .gray
        default: .secondary
        }
    }
}
