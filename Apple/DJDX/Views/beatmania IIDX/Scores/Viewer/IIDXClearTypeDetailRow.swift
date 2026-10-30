import SwiftUI

struct IIDXClearTypeDetailRow: View {
    var title: String
    var value: String

    init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            Text(title)
                .fontWidth(.expanded)
            Spacer()
            FullComboRainbowTimeline(isActive: value == IIDXClearType.fullComboClear.rawValue) { phase in
                Text(value)
                    .fontWeight(.black)
                    .foregroundStyle(IIDXClearType.style(for: value, phase: phase))
                    .strokeText(color: .black, width: 0.3)
            }
        }
        .font(.caption)
        .fontWeight(.heavy)
    }
}
