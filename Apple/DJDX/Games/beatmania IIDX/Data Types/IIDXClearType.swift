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

    static func color(for clearType: String) -> Color {
        switch clearType {
        case "FULLCOMBO CLEAR": return Color(red: 0.45, green: 0.85, blue: 1.0)
        case "CLEAR": return Color(red: 0.3, green: 0.85, blue: 0.98)
        case "EASY CLEAR": return Color(red: 0.7, green: 0.93, blue: 0.3)
        case "ASSIST CLEAR": return Color(red: 0.7, green: 0.5, blue: 1.0)
        case "HARD CLEAR": return Color(red: 1.0, green: 0.28, blue: 0.32)
        case "EX HARD CLEAR": return Color(red: 1.0, green: 0.82, blue: 0.22)
        case "FAILED": return Color(red: 0.98, green: 0.4, blue: 0.27)
        default: return Color(red: 0.66, green: 0.67, blue: 0.7)
        }
    }

    static var chartColorDomain: [String] {
        sortedStrings
    }

    static var chartColorRange: [Color] {
        sortedStrings.map { color(for: $0) }
    }

    static func chartColorRange(phase: Double) -> [Color] {
        sortedStrings.map { clearType in
            clearType == "FULLCOMBO CLEAR" ? FullComboRainbow.color(phase: phase) : color(for: clearType)
        }
    }

    static func style(for clearType: String, phase: Double = 0.0) -> any ShapeStyle {
        switch clearType {
        case "FULLCOMBO CLEAR": return FullComboRainbow.color(phase: phase)
        case "FAILED": return LinearGradient.metallic(
            highlight: Color(red: 1.0, green: 0.72, blue: 0.6),
            base: Color(red: 0.98, green: 0.4, blue: 0.27),
            shade: Color(red: 0.86, green: 0.25, blue: 0.14)
        )
        case "EASY CLEAR": return LinearGradient.metallic(
            highlight: Color(red: 0.93, green: 1.0, blue: 0.75),
            base: Color(red: 0.7, green: 0.93, blue: 0.3),
            shade: Color(red: 0.5, green: 0.8, blue: 0.12)
        )
        case "ASSIST CLEAR": return LinearGradient.metallic(
            highlight: Color(red: 0.9, green: 0.82, blue: 1.0),
            base: Color(red: 0.7, green: 0.5, blue: 1.0),
            shade: Color(red: 0.52, green: 0.3, blue: 0.92)
        )
        case "CLEAR": return LinearGradient.metallic(
            highlight: Color(red: 0.82, green: 1.0, blue: 1.0),
            base: Color(red: 0.3, green: 0.85, blue: 0.98),
            shade: Color(red: 0.1, green: 0.66, blue: 0.9)
        )
        case "HARD CLEAR": return LinearGradient.metallic(
            highlight: Color(red: 1.0, green: 0.72, blue: 0.74),
            base: Color(red: 1.0, green: 0.28, blue: 0.32),
            shade: Color(red: 0.86, green: 0.06, blue: 0.16)
        )
        case "EX HARD CLEAR": return LinearGradient.metallic(
            highlight: Color(red: 1.0, green: 0.97, blue: 0.72),
            base: Color(red: 1.0, green: 0.82, blue: 0.22),
            shade: Color(red: 0.93, green: 0.56, blue: 0.05)
        )
        case "NO PLAY": return LinearGradient.metallic(
            highlight: Color(red: 0.9, green: 0.91, blue: 0.92),
            base: Color(red: 0.66, green: 0.67, blue: 0.7),
            shade: Color(red: 0.5, green: 0.51, blue: 0.54)
        )
        default: return Color.primary
        }
    }
}
