import SwiftUI

struct IIDXDetailRow: View {
    var title: String
    var value: String
    var style: any ShapeStyle
    var outlineColor: Color
    var outlineWidth: CGFloat
    var isIIDXScore: Bool = false

    init(_ title: String, score: Int) {
        self.init(title, value: score, style: Color.iidxScore)
        self.isIIDXScore = true
    }

    init(_ title: String, value: String, style: any ShapeStyle,
         outlineColor: Color = .clear, outlineWidth: CGFloat = 0.0) {
        self.title = title
        self.value = value
        self.style = style
        self.outlineColor = outlineColor
        self.outlineWidth = outlineWidth
    }

    init(_ title: String, value: Int, style: any ShapeStyle,
         outlineColor: Color = .clear, outlineWidth: CGFloat = 0.0) {
        self.title = title
        self.value = String(value)
        self.style = style
        self.outlineColor = outlineColor
        self.outlineWidth = outlineWidth
    }

    var body: some View {
        HStack {
            Text(title)
                .cardLabel()
                .foregroundStyle(.secondary)
            Spacer()
            if isIIDXScore {
                IIDXScoreText(text: value, width: .condensed)
            } else {
                Text(value)
                    .font(.scoreline(.caption))
                    .fontWidth(.standard)
                    .foregroundStyle(style)
                    .strokeText(color: outlineColor, width: outlineWidth)
            }
        }
    }
}
