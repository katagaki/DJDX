import SwiftUI

enum PolarisChordClearType: String, Codable {
    case all = "Shared.All"
    case allPerfect = "ALL PERFECT"
    case fullCombo = "FULL COMBO"
    case success = "SUCCESS"
    case failed = "FAILED"
    case noPlay = "NO PLAY"
    case unknown = ""

    static let sorted: [PolarisChordClearType] = [
        .allPerfect, .fullCombo, .success, .failed, .noPlay
    ]

    static let sortedWithoutNoPlay: [PolarisChordClearType] = [
        .allPerfect, .fullCombo, .success, .failed
    ]

    static var sortedStringsWithoutNoPlay: [String] {
        sortedWithoutNoPlay.map { $0.rawValue }
    }

    // Maps the API's clear_status integer (4=perfect, 3=full, 2=success).
    init(statusCode: Int) {
        switch statusCode {
        case 4: self = .allPerfect
        case 3: self = .fullCombo
        case 2: self = .success
        case 1: self = .failed
        case 0: self = .noPlay
        default: self = .unknown
        }
    }

    var abbreviation: String {
        switch self {
        case .all: return "ALL"
        case .allPerfect: return "AP"
        case .fullCombo: return "FC"
        case .success: return "CLEAR"
        case .failed: return "FAIL"
        case .noPlay: return "NP"
        case .unknown: return ""
        }
    }

    var color: Color {
        switch self {
        case .allPerfect: return .yellow
        case .fullCombo: return .cyan
        case .success: return .green
        case .failed: return .red
        case .noPlay: return .gray
        default: return .secondary
        }
    }
}
