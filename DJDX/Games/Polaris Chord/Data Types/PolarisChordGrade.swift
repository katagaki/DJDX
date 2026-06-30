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

    func style(colorScheme: ColorScheme) -> any ShapeStyle {
        switch self {
        case .sssPlusPlus, .sssPlus, .sss:
            if colorScheme == .dark {
                return LinearGradient(
                    colors: [.cyan,
                             Color(red: 1.0, green: 0.96, blue: 0.72),
                             Color(red: 1.0, green: 0.72, blue: 0.86)],
                    startPoint: .leading, endPoint: .trailing
                )
            } else {
                return LinearGradient(
                    colors: [.blue, .yellow, .pink],
                    startPoint: .leading, endPoint: .trailing
                )
            }
        case .ss, .s:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.84, blue: 0.4),
                         Color(red: 0.85, green: 0.6, blue: 0.13)],
                startPoint: .top, endPoint: .bottom
            )
        default:
            if colorScheme == .dark {
                return LinearGradient(colors: [.white, .cyan],
                                      startPoint: .top, endPoint: .bottom)
            }
            return LinearGradient(colors: [.cyan, .blue],
                                  startPoint: .top, endPoint: .bottom)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
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
