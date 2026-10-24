import SwiftUI

enum Zoom {
    static let min: CGFloat = 1
    static let max: CGFloat = 8
    static let step: CGFloat = 1.5

    static func clamp(_ z: CGFloat) -> CGFloat { Swift.min(Swift.max(z, min), max) }
}

// Floating zoom bar: out / percentage / in / reset. Drives the same `zoom`
// (committed) and `pan` state the image views feed into EditorGeometry.
struct ZoomControls: View {
    @Binding var zoom: CGFloat
    @Binding var pan: CGSize

    var body: some View {
        HStack(spacing: 4) {
            Button { set(zoom / Zoom.step) } label: { Image(systemName: "minus.magnifyingglass") }
                .disabled(zoom <= Zoom.min)
                .help("Zoom out")
            Text("\(Int((zoom * 100).rounded()))%")
                .font(.caption.monospacedDigit())
                .frame(width: 42)
            Button { set(zoom * Zoom.step) } label: { Image(systemName: "plus.magnifyingglass") }
                .disabled(zoom >= Zoom.max)
                .help("Zoom in")
            Divider().frame(height: 14)
            Button { zoom = 1; pan = .zero } label: { Image(systemName: "arrow.counterclockwise") }
                .disabled(zoom == 1 && pan == .zero)
                .help("Reset zoom to 100%")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .glassEffect(.regular, in: Capsule())
        .padding(10)
    }

    private func set(_ z: CGFloat) {
        zoom = Zoom.clamp(z)
        if zoom == 1 { pan = .zero }
    }
}
