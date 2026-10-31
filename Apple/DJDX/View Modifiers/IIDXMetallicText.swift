import SwiftUI

struct IIDXMetallicText: View {
    let text: String
    let isFullCombo: Bool
    let style: (Double) -> any ShapeStyle
    let weight: Font.Weight
    let kerning: CGFloat

    var body: some View {
        FullComboRainbowTimeline(isActive: isFullCombo) { phase in
            Text(verbatim: text)
                .fontWeight(weight)
                .fontWidth(.expanded)
                .kerning(kerning)
                .foregroundStyle(style(phase))
                .strokeText(color: .black, width: 0.3)
        }
    }

    static func clearType(_ clearType: String, label: String? = nil) -> IIDXMetallicText {
        IIDXMetallicText(
            text: label ?? clearType,
            isFullCombo: clearType == IIDXClearType.fullComboClear.rawValue,
            style: { IIDXClearType.style(for: clearType, phase: $0) },
            weight: .heavy,
            kerning: -0.3
        )
    }

    static func djLevel(_ djLevel: String) -> IIDXMetallicText {
        IIDXMetallicText(
            text: djLevel,
            isFullCombo: false,
            style: { _ in IIDXDJLevel.style(for: djLevel) },
            weight: .black,
            kerning: 0.0
        )
    }
}
