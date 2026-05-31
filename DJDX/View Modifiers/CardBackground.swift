import SwiftUI

struct CardBackground: ViewModifier {

    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                switch colorScheme {
                case .light: Color.white
                case .dark: Color.clear.background(.regularMaterial)
                @unknown default: Color.clear
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
    }
}

extension View {
    func cardBackground(cornerRadius: CGFloat) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius))
    }
}
