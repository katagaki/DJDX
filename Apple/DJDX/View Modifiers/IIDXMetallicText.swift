import SwiftUI

struct IIDXMetallicText: View {
    let text: String
    let isFullCombo: Bool
    let style: (Double) -> any ShapeStyle
    var width: Font.Width = .standard
    var kerning: CGFloat = 0.0

    var body: some View {
        FullComboRainbowTimeline(isActive: isFullCombo) { phase in
            Text(verbatim: text)
                .fontWidth(width)
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
            width: .expanded,
            kerning: -0.3
        )
    }

    static func djLevel(_ djLevel: String) -> IIDXMetallicText {
        IIDXMetallicText(
            text: djLevel,
            isFullCombo: false,
            style: { _ in IIDXDJLevel.style(for: djLevel) }
        )
    }
}
