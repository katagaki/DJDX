import CoreText
import SwiftUI

struct IIDXScoreText: View {
    let text: String
    var width: ScorelineFont.Width
    @ScaledMetric var size: CGFloat

    init(_ score: Int, style: Font.TextStyle = .caption, width: ScorelineFont.Width = .standard) {
        self.init(text: String(score), style: style, width: width)
    }

    init(text: String, style: Font.TextStyle = .caption, width: ScorelineFont.Width = .standard) {
        self.text = text
        self.width = width
        self._size = ScaledMetric(wrappedValue: ScorelineFont.baseSize(for: style), relativeTo: style)
    }

    var body: some View {
        let glyphs = ScorelineGlyphs(text: text, fontName: ScorelineFont.name(weight: .heavy, width: width), size: size)
        let outline = size * 0.045
        ZStack {
            glyphs.path
                .stroke(Color.iidxScoreOutline, style: StrokeStyle(lineWidth: outline * 2.0, lineJoin: .round))
            glyphs.path
                .fill(Color.iidxScore)
        }
        .frame(width: glyphs.width, height: glyphs.ascent + glyphs.descent)
        .alignmentGuide(.firstTextBaseline) { _ in glyphs.ascent }
        .alignmentGuide(.lastTextBaseline) { _ in glyphs.ascent }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: text))
    }
}

struct ScorelineGlyphs {
    let path: Path
    let width: CGFloat
    let ascent: CGFloat
    let descent: CGFloat

    init(text: String, fontName: String, size: CGFloat) {
        let font = CTFontCreateWithName(fontName as CFString, size, nil)
        let attributed = NSAttributedString(string: text, attributes: [.init(kCTFontAttributeName as String): font])
        let line = CTLineCreateWithAttributedString(attributed)
        var ascent: CGFloat = 0.0
        var descent: CGFloat = 0.0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
        let combined = CGMutablePath()
        let runs = CTLineGetGlyphRuns(line) as? [CTRun] ?? []
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
            for index in 0..<count {
                var transform = CGAffineTransform(translationX: positions[index].x, y: ascent)
                    .scaledBy(x: 1.0, y: -1.0)
                if let glyphPath = CTFontCreatePathForGlyph(font, glyphs[index], &transform) {
                    combined.addPath(glyphPath)
                }
            }
        }
        self.path = Path(combined)
        self.width = width
        self.ascent = ascent
        self.descent = descent
    }
}
