import SwiftUI

enum IIDXClearType: String, Codable {
    case all = "Shared.All"
    case fullComboClear = "FULLCOMBO CLEAR"
    case clear = "CLEAR"
    case easyClear = "EASY CLEAR"
    case assistClear = "ASSIST CLEAR"
    case hardClear = "HARD CLEAR"
    case exHardClear = "EX HARD CLEAR"
    case failed = "FAILED"
    case noPlay = "NO PLAY"
    case unknown = ""

    static let sorted: [IIDXClearType] = [
        .fullComboClear,
        .clear,
        .easyClear,
        .assistClear,
        .hardClear,
        .exHardClear,
        .failed,
        .noPlay
    ]

    static let sortedWithoutNoPlay: [IIDXClearType] = [
        .fullComboClear,
        .clear,
        .easyClear,
        .assistClear,
        .hardClear,
        .exHardClear,
        .failed
    ]

    static let ascending: [IIDXClearType] = [
        .noPlay,
        .failed,
        .assistClear,
        .easyClear,
        .clear,
        .hardClear,
        .exHardClear,
        .fullComboClear
    ]

    static var sortedStrings: [String] {
        sorted.map({ $0.rawValue })
    }

    static var sortedStringsWithoutNoPlay: [String] {
        sortedWithoutNoPlay.map({ $0.rawValue })
    }

    // Short label for compact per-level stat rows.
    static func abbreviation(for clearType: String) -> String {
        switch clearType {
        case "FULLCOMBO CLEAR": return "F-COMBO"
        case "CLEAR": return "CLEAR"
        case "EASY CLEAR": return "E-CLEAR"
        case "ASSIST CLEAR": return "A-CLEAR"
        case "HARD CLEAR": return "H-CLEAR"
        case "EX HARD CLEAR": return "EXH-CLEAR"
        case "FAILED": return "FAILED"
        default: return clearType
        }
    }

    // Solid colors matching the clear-type chart palette.
    static func color(for clearType: String) -> Color {
        switch clearType {
        case "FULLCOMBO CLEAR": return .blue
        case "CLEAR": return .cyan
        case "EASY CLEAR": return .green
        case "ASSIST CLEAR": return .purple
        case "HARD CLEAR": return .pink
        case "EX HARD CLEAR": return .yellow
        case "FAILED": return .red
        default: return .gray
        }
    }

    static func style(for clearType: String) -> any ShapeStyle {
        switch clearType {
        case "FULLCOMBO CLEAR": return metallic(
            highlight: Color(red: 0.92, green: 1.0, blue: 1.0),
            base: Color(red: 0.45, green: 0.85, blue: 1.0),
            shade: Color(red: 0.62, green: 0.42, blue: 1.0)
        )
        case "FAILED": return metallic(
            highlight: Color(red: 1.0, green: 0.72, blue: 0.6),
            base: Color(red: 0.98, green: 0.4, blue: 0.27),
            shade: Color(red: 0.86, green: 0.25, blue: 0.14)
        )
        case "EASY CLEAR": return metallic(
            highlight: Color(red: 0.93, green: 1.0, blue: 0.75),
            base: Color(red: 0.7, green: 0.93, blue: 0.3),
            shade: Color(red: 0.5, green: 0.8, blue: 0.12)
        )
        case "ASSIST CLEAR": return metallic(
            highlight: Color(red: 0.9, green: 0.82, blue: 1.0),
            base: Color(red: 0.7, green: 0.5, blue: 1.0),
            shade: Color(red: 0.52, green: 0.3, blue: 0.92)
        )
        case "CLEAR": return metallic(
            highlight: Color(red: 0.82, green: 1.0, blue: 1.0),
            base: Color(red: 0.3, green: 0.85, blue: 0.98),
            shade: Color(red: 0.1, green: 0.66, blue: 0.9)
        )
        case "HARD CLEAR": return metallic(
            highlight: Color(red: 1.0, green: 0.72, blue: 0.74),
            base: Color(red: 1.0, green: 0.28, blue: 0.32),
            shade: Color(red: 0.86, green: 0.06, blue: 0.16)
        )
        case "EX HARD CLEAR": return metallic(
            highlight: Color(red: 1.0, green: 0.97, blue: 0.72),
            base: Color(red: 1.0, green: 0.82, blue: 0.22),
            shade: Color(red: 0.93, green: 0.56, blue: 0.05)
        )
        default: return Color.primary
        }
    }

    private static func metallic(highlight: Color, base: Color, shade: Color) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: highlight, location: 0.0),
                .init(color: highlight, location: 0.2),
                .init(color: base, location: 0.48),
                .init(color: shade, location: 0.52),
                .init(color: base, location: 0.85),
                .init(color: highlight, location: 1.0)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }
}
