import SwiftUI

struct ShareCardMetric: Identifiable {
    let id = UUID()
    let text: String
    let style: AnyShapeStyle

    init(_ text: String, style: some ShapeStyle) {
        self.text = text
        self.style = AnyShapeStyle(style)
    }
}

struct ShareCardEntry: Identifiable {
    let id = UUID()
    let title: String
    var subtitle: String?
    let lampStyle: AnyShapeStyle
    let levelText: String
    let difficultyText: String
    let difficultyColor: Color
    var metrics: [ShareCardMetric]
}

struct ShareCardRating: Identifiable {
    var id: String { label + value }
    let label: String
    let value: String
}

struct ShareCardProfile {
    var playerName: String?
    var ratings: [ShareCardRating] = []
    var avatar: UIImage?
    var radar: RadarData?

    var isEmpty: Bool {
        (playerName?.isEmpty ?? true) && ratings.isEmpty && !hasVisuals
    }

    var hasVisuals: Bool {
        avatar != nil || radar != nil
    }
}

enum ShareCardGradient: String, CaseIterable, Identifiable {
    case accent
    case midnight
    case sunset
    case ocean
    case aurora
    case mono

    var id: String { rawValue }

    func colors(accentColor: Color) -> [Color] {
        switch self {
        case .accent: [accentColor, accentColor.mix(with: .black, by: 0.75)]
        case .midnight: [Color(red: 0.16, green: 0.12, blue: 0.36), Color(red: 0.02, green: 0.02, blue: 0.1)]
        case .sunset: [Color(red: 0.98, green: 0.45, blue: 0.33), Color(red: 0.45, green: 0.11, blue: 0.42)]
        case .ocean: [Color(red: 0.0, green: 0.62, blue: 0.82), Color(red: 0.03, green: 0.14, blue: 0.36)]
        case .aurora: [Color(red: 0.2, green: 0.85, blue: 0.6), Color(red: 0.24, green: 0.16, blue: 0.55)]
        case .mono: [Color(white: 0.28), Color(white: 0.05)]
        }
    }
}

enum ShareCardBackground: Hashable {
    case gradient(ShareCardGradient)
    case appIcon(String)
    case photo
}
