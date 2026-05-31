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
        case "FAILED": return "FAIL"
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

    static func style(for clearType: String, colorScheme: ColorScheme) -> any ShapeStyle {
        func whiteOr(_ color: Color) -> Color {
            colorScheme == .dark ? .white : color
        }
        switch clearType {
        case "FULLCOMBO CLEAR": return LinearGradient(
            gradient: Gradient(colors: [.cyan, whiteOr(.blue), .purple]),
            startPoint: .top, endPoint: .bottom
        )
        case "FAILED": return LinearGradient(
            gradient: Gradient(colors: [.orange, .red, .orange]),
            startPoint: .top, endPoint: .bottom
        )
        case "EASY CLEAR": return LinearGradient(
            gradient: Gradient(colors: [whiteOr(.mint), .green, whiteOr(.mint)]),
            startPoint: .top, endPoint: .bottom
        )
        case "ASSIST CLEAR": return LinearGradient(
            gradient: Gradient(colors: [whiteOr(.indigo), .purple, whiteOr(.indigo)]),
            startPoint: .top, endPoint: .bottom
        )
        case "CLEAR": return LinearGradient(
            gradient: Gradient(colors: [whiteOr(.blue), .cyan, whiteOr(.blue)]),
            startPoint: .top, endPoint: .bottom
        )
        case "HARD CLEAR": return LinearGradient(
            gradient: Gradient(colors: [whiteOr(.red), .pink, whiteOr(.red)]),
            startPoint: .top, endPoint: .bottom
        )
        case "EX HARD CLEAR": return LinearGradient(
            gradient: Gradient(colors: [whiteOr(.orange), .yellow, whiteOr(.orange)]),
            startPoint: .top, endPoint: .bottom
        )
        default: return Color.primary
        }
    }
}
