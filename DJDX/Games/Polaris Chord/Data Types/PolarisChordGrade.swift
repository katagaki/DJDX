import SwiftUI

enum PolarisChordGrade: String, Codable {
    // swiftlint:disable identifier_name
    case all = "Shared.All"
    case sssPlusPlus = "SSS++"
    case sssPlus = "SSS+"
    case sss = "SSS"
    case ss = "SS"
    case s = "S"
    case aaa = "AAA"
    case aa = "AA"
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case none = "---"
    case unknown = ""
    // swiftlint:enable identifier_name

    // Best-to-worst order (the S tier ranks above the A tier in Polaris Chord).
    static let sorted: [PolarisChordGrade] = [
        .sssPlusPlus, .sssPlus, .sss, .ss, .s, .aaa, .aa, .a, .b, .c, .d
    ]

    static var sortedStrings: [String] {
        sorted.map { $0.rawValue }
    }

    // Derived from achievement_rate (integer hundredths) using the site's own
    // thresholds; SSS++ requires a perfect 100.00%.
    init(achievementRate: Int) {
        switch achievementRate {
        case 10000...: self = .sssPlusPlus
        case 9951...: self = .sssPlus
        case 9901...: self = .sss
        case 9851...: self = .ss
        case 9801...: self = .s
        case 9501...: self = .aaa
        case 9001...: self = .aa
        case 8501...: self = .a
        case 8001...: self = .b
        case 7001...: self = .c
        case 1...: self = .d
        default: self = .none
        }
    }
}
