import SwiftUI

struct SDVXDetailRow: View {
    var title: String
    var value: String
    var style: any ShapeStyle

    init(_ title: String, value: String, style: any ShapeStyle) {
        self.title = title
        self.value = value
        self.style = style
    }

    init(_ title: String, value: Int, style: any ShapeStyle) {
        self.title = title
        self.value = value.formatted(.number)
        self.style = style
    }

    var body: some View {
        HStack {
            Text(verbatim: title)
            Spacer()
            Text(verbatim: value)
                .foregroundStyle(style)
        }
        .fontWidth(.expanded)
        .font(.caption)
        .fontWeight(.heavy)
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
