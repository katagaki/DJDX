import SwiftUI

enum PopnRank: String, Codable, CaseIterable {
    case s = "S"
    case aaa = "AAA"
    case aaPlus = "AA+"
    case aa = "AA"
    case aPlus = "A+"
    case a = "A"
    case bPlus = "B+"
    case b = "B"
    case c = "C"
    case d = "D"
    case e = "E"
    case none = "---"

    static let sorted: [PopnRank] = [.s, .aaa, .aaPlus, .aa, .aPlus, .a, .bPlus, .b, .c, .d, .e]

    static var sortedStrings: [String] {
        sorted.map { $0.rawValue }
    }

    init(code: String) {
        switch code.lowercased() {
        case "s": self = .s
        case "a3": self = .aaa
        case "a2_plus": self = .aaPlus
        case "a2": self = .aa
        case "a1_plus": self = .aPlus
        case "a1": self = .a
        case "b_plus": self = .bPlus
        case "b": self = .b
        case "c": self = .c
        case "d": self = .d
        case "e": self = .e
        default: self = .none
        }
    }

    var color: Color {
        switch self {
        case .s: .orange
        case .aaa: .yellow
        case .aaPlus, .aa: Color(red: 0.85, green: 0.6, blue: 0.13)
        case .aPlus, .a: .cyan
        case .bPlus, .b: .blue
        case .c: .indigo
        case .d: .purple
        case .e: .gray
        case .none: .secondary
        }
    }

    func style(colorScheme: ColorScheme) -> any ShapeStyle {
        switch self {
        case .s:
            return LinearGradient(
                colors: colorScheme == .dark ? [.yellow, .orange] : [.orange, .red],
                startPoint: .top, endPoint: .bottom
            )
        case .aaa, .aaPlus, .aa:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.84, blue: 0.4),
                         Color(red: 0.85, green: 0.6, blue: 0.13)],
                startPoint: .top, endPoint: .bottom
            )
        default:
            if colorScheme == .dark {
                return LinearGradient(colors: [.white, .cyan], startPoint: .top, endPoint: .bottom)
            }
            return LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
        }
    }
}
