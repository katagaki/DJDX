import SwiftUI

struct SDVXDetailRow: View {
    var title: String
    var value: String
    var style: any ShapeStyle
    var outlineColor: Color
    var outlineWidth: CGFloat

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
        self.value = value.formatted(.number)
        self.style = style
        self.outlineColor = outlineColor
        self.outlineWidth = outlineWidth
    }

    var body: some View {
        HStack {
            Text(verbatim: title)
            Spacer()
            Text(verbatim: value)
                .foregroundStyle(style)
                .strokeText(color: outlineColor, width: outlineWidth)
        }
        .fontWidth(.expanded)
        .font(.caption)
        .fontWeight(.heavy)
    }
}

struct SDVXScoreDetailRow: View {
    var title: String
    var value: Int

    init(_ title: String, value: Int) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            Text(verbatim: title)
                .fontWidth(.expanded)
                .fontWeight(.heavy)
            Spacer()
            Text(value, format: .number)
                .sdvxScoreText()
        }
        .font(.caption)
    }
}

struct SDVXNoteTypeDetailRow: View {
    var title: String
    var value: String
    var style: any ShapeStyle

    init(_ title: String, value: Int, style: any ShapeStyle) {
        self.title = title
        self.value = value.formatted(.number)
        self.style = style
    }

    var body: some View {
        VStack(spacing: 4.0) {
            Text(verbatim: title)
                .foregroundStyle(style)
            Text(verbatim: value)
        }
        .frame(maxWidth: .infinity)
        .fontWidth(.expanded)
        .font(.caption)
        .fontWeight(.heavy)
    }
}
