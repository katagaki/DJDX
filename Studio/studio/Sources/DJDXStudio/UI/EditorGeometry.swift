import CoreGraphics

// Letterbox transform between normalised [0,1] image space and view points.
struct EditorGeometry {
    var offset: CGPoint
    var displaySize: CGSize

    init(container: CGSize, imagePixelSize: CGSize) {
        guard imagePixelSize.width > 0, imagePixelSize.height > 0 else {
            offset = .zero; displaySize = container; return
        }
        let scale = min(container.width / imagePixelSize.width,
                        container.height / imagePixelSize.height)
        let dw = imagePixelSize.width * scale
        let dh = imagePixelSize.height * scale
        displaySize = CGSize(width: dw, height: dh)
        offset = CGPoint(x: (container.width - dw) / 2, y: (container.height - dh) / 2)
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
