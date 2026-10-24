import SwiftUI

struct AdaptiveClipShape: ViewModifier {
    func body(content: Content) -> some View {
        content
            .clipShape(.rect(cornerRadius: 12.0))
    }
}

extension View {
    func adaptiveClipShape() -> some View {
        modifier(AdaptiveClipShape())
    }
}
