import SwiftUI

struct SDVXScoreText: ViewModifier {
    var outlineWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .fontWidth(.standard)
            .fontWeight(.semibold)
            .monospacedDigit()
            .foregroundStyle(LinearGradient(
                stops: [
                    .init(color: Color(red: 0.7, green: 0.78, blue: 0.87), location: 0.0),
                    .init(color: Color(red: 0.73, green: 0.81, blue: 0.89), location: 0.52),
                    .init(color: Color(red: 0.86, green: 0.91, blue: 0.96), location: 0.56),
                    .init(color: Color(red: 0.95, green: 0.97, blue: 0.98), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            ))
            .strokeText(color: Color(red: 0.11, green: 0.2, blue: 0.32), width: outlineWidth)
    }
}

extension View {
    func sdvxScoreText(outlineWidth: CGFloat = 0.3) -> some View {
        modifier(SDVXScoreText(outlineWidth: outlineWidth))
    }
}
