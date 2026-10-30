import SwiftUI

struct IIDXClearTypeDetailRow: View {
    var title: String
    var value: String
    var style: any ShapeStyle

    init(_ title: String, value: String, style: any ShapeStyle) {
        self.title = title
        self.value = value
        self.style = style
    }

    var body: some View {
        HStack {
            Text(title)
                .fontWidth(.expanded)
            Spacer()
            Text(value)
                .foregroundStyle(style)
                .strokeText(color: .black, width: 0.3)
        }
        .font(.caption)
        .fontWeight(.heavy)
    }
}
