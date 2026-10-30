import SwiftUI

struct SDVXScoreText: ViewModifier {
    var outlineWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .fontWidth(.standard)
            .fontWeight(.semibold)
            .monospacedDigit()
            .foregroundStyle(LinearGradient.sdvxScore)
            .strokeText(color: .sdvxScoreOutline, width: outlineWidth)
    }
}

extension View {
    func sdvxScoreText(outlineWidth: CGFloat = 0.3) -> some View {
        modifier(SDVXScoreText(outlineWidth: outlineWidth))
    }

    func sdvxGradeText(outlineWidth: CGFloat = 0.3) -> some View {
        foregroundStyle(LinearGradient.sdvxGrade)
            .strokeText(color: .sdvxGradeOutline, width: outlineWidth)
    }
}

extension LinearGradient {
    static let sdvxScore = twoTone(
        top: Color(red: 0.71, green: 0.79, blue: 0.88),
        bottom: Color(red: 0.86, green: 0.91, blue: 0.96),
        bottomEdge: Color(red: 0.95, green: 0.97, blue: 0.98)
    )

    static let sdvxGrade = twoTone(
        top: Color(red: 0.92, green: 0.84, blue: 0.64),
        bottom: Color(red: 0.94, green: 0.72, blue: 0.12),
        bottomEdge: Color(red: 0.93, green: 0.76, blue: 0.24)
    )

    private static func twoTone(top: Color, bottom: Color, bottomEdge: Color) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: top, location: 0.0),
                .init(color: top, location: 0.52),
                .init(color: bottom, location: 0.56),
                .init(color: bottomEdge, location: 1.0)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }
}

extension Color {
    static let sdvxScoreOutline = Color(red: 0.11, green: 0.2, blue: 0.32)
    static let sdvxGradeOutline = Color(red: 0.26, green: 0.16, blue: 0.06)
}
