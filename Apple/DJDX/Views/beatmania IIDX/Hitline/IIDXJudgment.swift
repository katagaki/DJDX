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

    private let outlineScale: CGFloat = 0.6

    private var displayText: String { text ?? judgment.label }

    var body: some View {
        Group {
            if let style = judgment.style {
                HitlineJudgmentText(text: displayText, size: size, style: style, outlineScale: outlineScale)
            } else {
                HitlineRainbowText(text: displayText, size: size, outlineScale: outlineScale)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: text ?? judgment.accessibilityName))
    }
}

struct IIDXJudgmentBreakdown: View {
    var entries: [(judgment: IIDXJudgment, value: Int)]

    private let size: CGFloat = 24.0

    var body: some View {
        VStack(spacing: 10.0) {
            ForEach(entries.indices, id: \.self) { index in
                HStack(spacing: 0.0) {
                    IIDXJudgmentLabel(judgment: entries[index].judgment, size: size)
                    Spacer(minLength: 0.0)
                    IIDXJudgmentLabel(
                        judgment: entries[index].judgment,
                        text: String(entries[index].value),
                        size: size
                    )
                }
            }
        }
    }
}
