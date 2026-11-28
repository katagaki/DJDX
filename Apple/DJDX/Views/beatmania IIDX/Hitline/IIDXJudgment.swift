import SwiftUI

enum IIDXJudgment {
    case perfectGreat
    case great
    case good
    case bad
    case poor
    case miss

    var label: String {
        switch self {
        case .perfectGreat, .great: "GREAT"
        case .good: "GOOD"
        case .bad: "BAD"
        case .poor: "POOR"
        case .miss: "MISS"
        }
    }

    var accessibilityName: String {
        self == .perfectGreat ? "P-GREAT" : label
    }

    var style: HitlineJudgmentStyle? {
        switch self {
        case .perfectGreat: nil
        case .great: .great
        case .good: .good
        case .bad: .bad
        case .poor, .miss: .poor
        }
    }
}

struct IIDXJudgmentLabel: View {
    var judgment: IIDXJudgment
    var text: String?
    var size: CGFloat
    var outlineScale: CGFloat?

    private var resolvedOutlineScale: CGFloat { outlineScale ?? size * 0.025 }

    private var displayText: String { text ?? judgment.label }

    var body: some View {
        Group {
            if let style = judgment.style {
                HitlineJudgmentText(text: displayText, size: size, style: style, outlineScale: resolvedOutlineScale)
            } else {
                HitlineRainbowText(text: displayText, size: size, outlineScale: resolvedOutlineScale)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: text ?? judgment.accessibilityName))
    }
}
