import SwiftUI

struct IIDXDetailRow: View {
    var title: String
    var value: String
    var style: any ShapeStyle
    var outlineWidth: CGFloat

    init(_ title: String, value: String, style: any ShapeStyle, outlineWidth: CGFloat = 0.0) {
        self.title = title
        self.value = value
        self.style = style
        self.outlineWidth = outlineWidth
    }

    init(_ title: String, value: Int, style: any ShapeStyle, outlineWidth: CGFloat = 0.0) {
        self.title = title
        self.value = String(value)
        self.style = style
        self.outlineWidth = outlineWidth
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(style)
                .strokeText(color: .black, width: outlineWidth)
        }
        .fontWidth(.expanded)
        .font(.caption)
        .fontWeight(.heavy)
    }
}
