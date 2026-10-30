import SwiftUI

enum IIDXDJLevel: String, Codable {
    case all = "Shared.All"
    case djAAA = "AAA"
    case djAA = "AA"
    case djA = "A"
    case djB = "B"
    case djC = "C"
    case djD = "D"
    case djE = "E"
    case djF = "F"
    case none = "---"

    static let sorted: [IIDXDJLevel] = [
        .djF,
        .djE,
        .djD,
        .djC,
        .djB,
        .djA,
        .djAA,
        .djAAA
    ]
    static var sortedStrings: [String] {
        sorted.map({ $0.rawValue })
    }

    static func < (lhs: IIDXDJLevel, rhs: IIDXDJLevel) -> Bool {
        sorted.firstIndex(of: lhs) ?? 1 < sorted.firstIndex(of: rhs) ?? 0
    }

    static func color(for djLevel: String) -> Color {
        switch djLevel {
        case "AAA": return Color(red: 1.0, green: 0.8, blue: 0.16)
        case "AA": return Color(red: 0.62, green: 0.65, blue: 0.68)
        case "A": return Color(red: 0.4, green: 0.9, blue: 0.8)
        case "B": return Color(red: 0.32, green: 0.84, blue: 0.92)
        case "C": return Color(red: 0.24, green: 0.7, blue: 0.96)
        case "D": return Color(red: 0.24, green: 0.56, blue: 0.98)
        case "E": return Color(red: 0.2, green: 0.44, blue: 0.96)
        case "F": return Color(red: 0.16, green: 0.34, blue: 0.92)
        default: return .gray
        }
    }

    static var chartColorDomain: [String] {
        sorted.reversed().map(\.rawValue)
    }

    static var chartColorRange: [Color] {
        chartColorDomain.map { color(for: $0) }
    }

    static func style(for djLevel: String) -> any ShapeStyle {
        switch djLevel {
        case "AAA": return LinearGradient.metallic(
            highlight: Color(red: 1.0, green: 0.96, blue: 0.62),
            base: Color(red: 1.0, green: 0.8, blue: 0.16),
            shade: Color(red: 0.96, green: 0.56, blue: 0.0)
        )
        case "AA": return LinearGradient.metallic(
            highlight: Color(red: 1.0, green: 1.0, blue: 1.0),
            base: Color(red: 0.84, green: 0.86, blue: 0.88),
            shade: Color(red: 0.62, green: 0.65, blue: 0.68)
        )
        case "A": return LinearGradient.metallic(
            highlight: Color(red: 0.8, green: 1.0, blue: 0.94),
            base: Color(red: 0.4, green: 0.9, blue: 0.8),
            shade: Color(red: 0.2, green: 0.76, blue: 0.68)
        )
        case "B": return LinearGradient.metallic(
            highlight: Color(red: 0.78, green: 0.98, blue: 1.0),
            base: Color(red: 0.32, green: 0.84, blue: 0.92),
            shade: Color(red: 0.14, green: 0.68, blue: 0.82)
        )
        case "C": return LinearGradient.metallic(
            highlight: Color(red: 0.74, green: 0.92, blue: 1.0),
            base: Color(red: 0.24, green: 0.7, blue: 0.96),
            shade: Color(red: 0.1, green: 0.52, blue: 0.88)
        )
        case "D": return LinearGradient.metallic(
            highlight: Color(red: 0.7, green: 0.84, blue: 1.0),
            base: Color(red: 0.24, green: 0.56, blue: 0.98),
            shade: Color(red: 0.1, green: 0.4, blue: 0.9)
        )
        case "E": return LinearGradient.metallic(
            highlight: Color(red: 0.66, green: 0.78, blue: 1.0),
            base: Color(red: 0.2, green: 0.44, blue: 0.96),
            shade: Color(red: 0.08, green: 0.3, blue: 0.86)
        )
        case "F": return LinearGradient.metallic(
            highlight: Color(red: 0.62, green: 0.72, blue: 1.0),
            base: Color(red: 0.16, green: 0.34, blue: 0.92),
            shade: Color(red: 0.06, green: 0.2, blue: 0.8)
        )
        default: return Color.primary
        }
    }
}
