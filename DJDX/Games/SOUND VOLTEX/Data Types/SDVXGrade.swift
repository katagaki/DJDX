import SwiftUI

// Maps to the スコアグレード column in the SDVX CSV.
enum SDVXGrade: String, Codable {
    // swiftlint:disable identifier_name
    case all = "Shared.All"
    case s = "S"
    case aaaPlus = "AAA+"
    case aaa = "AAA"
    case aaPlus = "AA+"
    case aa = "AA"
    case aPlus = "A+"
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case none = "---"
    case unknown = ""
    // swiftlint:enable identifier_name

    static let sorted: [SDVXGrade] = [
        .s, .aaaPlus, .aaa, .aaPlus, .aa, .aPlus, .a, .b, .c, .d
    ]

    static var sortedStrings: [String] {
        sorted.map { $0.rawValue }
    }

    // Minimum score (out of 10,000,000) required for each grade
    static func grade(forScore score: Int) -> SDVXGrade {
        switch score {
        case 9_900_000...: return .s
        case 9_800_000..<9_900_000: return .aaaPlus
        case 9_700_000..<9_800_000: return .aaa
        case 9_500_000..<9_700_000: return .aaPlus
        case 9_300_000..<9_500_000: return .aa
        case 9_000_000..<9_300_000: return .aPlus
        case 8_700_000..<9_000_000: return .a
        case 7_500_000..<8_700_000: return .b
        case 6_500_000..<7_500_000: return .c
        case 1..<6_500_000: return .d
        default: return .none
        }
    }
}
