import CoreGraphics

// Letterbox transform between normalised [0,1] image space and view points,
// with optional zoom (≥1) and pan. Boxes, hit-testing and drag math all read
// `offset`/`displaySize`, so they keep working unchanged at any zoom level.
struct EditorGeometry {
    var offset: CGPoint
    var displaySize: CGSize
    var baseSize: CGSize       // fit size at zoom 1, before panning
    var container: CGSize

    init(container: CGSize, imagePixelSize: CGSize, zoom: CGFloat = 1, pan: CGSize = .zero) {
        self.container = container
        guard imagePixelSize.width > 0, imagePixelSize.height > 0 else {
            offset = .zero; displaySize = container; baseSize = container; return
        }
        let fit = min(container.width / imagePixelSize.width,
                      container.height / imagePixelSize.height)
        baseSize = CGSize(width: imagePixelSize.width * fit, height: imagePixelSize.height * fit)
        let dw = baseSize.width * zoom
        let dh = baseSize.height * zoom
        displaySize = CGSize(width: dw, height: dh)
        let p = EditorGeometry.clampPan(pan, container: container, display: displaySize)
        offset = CGPoint(x: (container.width - dw) / 2 + p.width,
                         y: (container.height - dh) / 2 + p.height)
    }

    // Keep the image from being panned entirely out of view: pan is limited to
    // the overflow half-extent on each axis (0 when the image fits).
    static func clampPan(_ pan: CGSize, container: CGSize, display: CGSize) -> CGSize {
        let mx = max(0, (display.width - container.width) / 2)
        let my = max(0, (display.height - container.height) / 2)
        return CGSize(width: min(max(pan.width, -mx), mx),
                      height: min(max(pan.height, -my), my))
    }

    func toView(x: Double, y: Double) -> CGPoint {
        CGPoint(x: offset.x + x * displaySize.width,
                y: offset.y + y * displaySize.height)
    }

    func rect(for b: Box) -> CGRect {
        let p = toView(x: b.x, y: b.y)
        return CGRect(x: p.x, y: p.y, width: b.w * displaySize.width, height: b.h * displaySize.height)
    }

    func toNorm(_ p: CGPoint) -> (x: Double, y: Double) {
        let x = (p.x - offset.x) / displaySize.width
        let y = (p.y - offset.y) / displaySize.height
        return (min(max(x, 0), 1), min(max(y, 0), 1))
    }
}
