import SwiftUI

struct InkOutline: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if colorScheme == .dark {
            content
                .shadow(color: .white, radius: 0.6)
                .shadow(color: .white, radius: 0.6)
                .shadow(color: .white.opacity(0.6), radius: 2.0)
        } else {
            content
        }
    }
}

extension View {
    func inkOutline() -> some View {
        modifier(InkOutline())
    }
}
