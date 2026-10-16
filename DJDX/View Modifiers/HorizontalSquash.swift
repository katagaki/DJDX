import SwiftUI

struct HorizontalSquash: ViewModifier {
    @State private var naturalWidth: CGFloat = .zero
    @State private var availableWidth: CGFloat = .zero

    var scale: CGFloat {
        guard naturalWidth > .zero, availableWidth > .zero, naturalWidth > availableWidth else { return 1.0 }
        return availableWidth / naturalWidth
    }

    func body(content: Content) -> some View {
        content
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                naturalWidth = width
            }
            .scaleEffect(x: scale, y: 1.0, anchor: .leading)
            .frame(minWidth: .zero, maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                availableWidth = width
            }
    }
}

extension View {
    func squashedHorizontally() -> some View {
        modifier(HorizontalSquash())
    }
}
