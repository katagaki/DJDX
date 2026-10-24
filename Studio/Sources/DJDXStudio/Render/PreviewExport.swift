import AppKit
import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers

// Ports draw_labels.py: render boxes + class tags onto the image and write a
// JPEG. Uses per-class colours (the labeller palette) rather than flat red.
enum PreviewExport {
    @discardableResult
    static func render(image cg: CGImage, boxes: [Box], to url: URL, quality: CGFloat = 0.85) -> Bool {
        let iw = cg.width, ih = cg.height
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: iw, pixelsHigh: ih,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        guard let rep else { return false }

        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return false }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        let g = ctx.cgContext

        g.draw(cg, in: CGRect(x: 0, y: 0, width: iw, height: ih))

        let lineW = max(2.0, Double(iw) / 500.0)
        let fontSize = max(9.0, Double(iw) / 110.0)
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)

        for b in boxes {
            let color = NSColor(Color(hex: ClassColor.hex(for: b.cls)))
            // labels.json y is top-left origin; flip to AppKit's bottom-left.
            let rect = CGRect(
                x: b.x * Double(iw),
                y: (1 - b.y - b.h) * Double(ih),
                width: b.w * Double(iw),
                height: b.h * Double(ih))
            color.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = lineW
            path.stroke()

            var tag = b.cls
            if let c = b.conf { tag += String(format: " %.2f", c) }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white,
                .backgroundColor: color,
            ]
            let str = NSAttributedString(string: " \(tag) ", attributes: attrs)
            let ts = str.size()
            let ty = rect.maxY + 1
            let drawY = (ty + ts.height) <= Double(ih) ? ty : rect.minY - ts.height - 1
            str.draw(at: CGPoint(x: rect.minX, y: max(0, drawY)))
        }

        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.representation(
            using: .jpeg, properties: [.compressionFactor: quality]) else { return false }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
            return true
        } catch {
            return false
        }
    }
}
