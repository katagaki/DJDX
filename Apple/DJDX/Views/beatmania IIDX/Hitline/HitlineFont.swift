import CoreText
import SwiftUI

enum HitlineFont {
    static let ascent: CGFloat = 0.85

    private nonisolated(unsafe) static let graphicsFont: CGFont = {
        guard let url = Bundle.main.url(forResource: "Hitline-Black", withExtension: "ttf"),
              let provider = CGDataProvider(url: url as CFURL),
              let font = CGFont(provider) else {
            fatalError("Hitline-Black.ttf is missing from the bundle")
        }
        return font
    }()

    static func coreText(size: CGFloat) -> CTFont {
        CTFontCreateWithGraphicsFont(graphicsFont, size, nil, nil)
    }

    static func swiftUI(size: CGFloat) -> Font {
        Font(coreText(size: size))
    }
}

struct HitlineOutline: Shape {
    let outline: Path
    let width: CGFloat

    init(text: String, size: CGFloat) {
        let font = HitlineFont.coreText(size: size)
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attributed)
        let baseline = size * HitlineFont.ascent
        var outline = Path()
        for run in CTLineGetGlyphRuns(line) as? [CTRun] ?? [] {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
            for (glyph, position) in zip(glyphs, positions) {
                var transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: position.x, ty: baseline)
                if let path = CTFontCreatePathForGlyph(font, glyph, &transform) {
                    outline.addPath(Path(path))
                }
            }
        }
        self.outline = outline
        width = CTLineGetTypographicBounds(line, nil, nil, nil)
    }

    func path(in rect: CGRect) -> Path {
        outline
    }
}
