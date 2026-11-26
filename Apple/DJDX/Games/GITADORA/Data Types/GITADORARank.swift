import SwiftUI

enum GITADORARank: String, Codable {
    case all = "Shared.All"
    case ss = "SS"
    case s = "S"
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case e = "E"
    case none = "---"
    case unknown = ""

    static let sorted: [GITADORARank] = [.ss, .s, .a, .b, .c, .d, .e]

    static var sortedStrings: [String] {
        sorted.map { $0.rawValue }
    }

    init(achievementRate: Double) {
        switch achievementRate {
        case 95.0...: self = .ss
        case 80.0...: self = .s
        case 73.0...: self = .a
        case 63.0...: self = .b
        case 53.0...: self = .c
        case 0.01...: self = .d
        default: self = .none
        }
    }

    static func color(for rawValue: String) -> Color {
        switch GITADORARank(rawValue: rawValue) {
        case .ss: .yellow
        case .s: .orange
        case .a: .red
        case .b: .purple
        case .c: .blue
        case .d: .teal
        default: .gray
        }
    }

    func style(colorScheme: ColorScheme) -> any ShapeStyle {
        switch self {
        case .ss:
            return LinearGradient(
                colors: colorScheme == .dark
                    ? [.cyan, Color(red: 1.0, green: 0.96, blue: 0.72), Color(red: 1.0, green: 0.72, blue: 0.86)]
                    : [.blue, .yellow, .pink],
                startPoint: .leading, endPoint: .trailing
            )
        case .s:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.84, blue: 0.4), Color(red: 0.85, green: 0.6, blue: 0.13)],
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
