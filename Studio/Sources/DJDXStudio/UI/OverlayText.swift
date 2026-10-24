import SwiftUI
import AppKit

extension GraphicsContext {
    // Draws a class tag with a translucent dark backing pill so the coloured
    // text stays legible over busy result-screen backgrounds.
    func drawTag(_ tag: String, color: Color, topLeft: CGPoint,
                 fontSize: CGFloat = 11, bold: Bool = false) {
        let text = Text(tag).font(.system(size: fontSize, weight: bold ? .bold : .regular))
        let resolved = resolve(text.foregroundStyle(Self.readable(color)))
        let size = resolved.measure(in: CGSize(width: 2000, height: 100))
        let padX: CGFloat = 4, padY: CGFloat = 2
        let rect = CGRect(x: topLeft.x, y: topLeft.y,
                          width: size.width + padX * 2, height: size.height + padY * 2)
        fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(.black.opacity(0.6)))
        draw(resolved, at: CGPoint(x: rect.minX + padX, y: rect.midY), anchor: .leading)
    }

    // Keep the hue for colour-coding but raise brightness so darker class
    // colours stay readable against the dark backing pill.
    private static func readable(_ color: Color,
                                 minBrightness: CGFloat = 1.0,
                                 maxSaturation: CGFloat = 0.6) -> Color {
        guard let ns = NSColor(color).usingColorSpace(.deviceRGB) else { return color }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h),
                     saturation: Double(min(s, maxSaturation)),
                     brightness: Double(max(b, minBrightness)))
    }
}
