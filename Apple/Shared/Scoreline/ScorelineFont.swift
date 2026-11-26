import CoreText
import SwiftUI

enum ScorelineFont {
    enum Weight: String {
        case regular = "Regular"
        case medium = "Medium"
        case bold = "Bold"
        case heavy = "Heavy"
    }

    enum Width: String {
        case condensed = "Condensed"
        case standard = ""
        case expanded = "Expanded"
    }

    private static let registered: Void = {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls where url.lastPathComponent.hasPrefix("Scoreline-") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    static func name(weight: Weight, width: Width) -> String {
        _ = registered
        return "Scoreline-\(width.rawValue)\(weight.rawValue)"
    }

    private static let baseSizes: [Font.TextStyle: CGFloat] = [
        .largeTitle: 34.0, .title: 28.0, .title2: 22.0, .title3: 20.0,
        .headline: 17.0, .body: 17.0, .callout: 16.0, .subheadline: 15.0,
        .footnote: 13.0, .caption: 12.0, .caption2: 11.0
    ]

    static func baseSize(for style: Font.TextStyle) -> CGFloat {
        baseSizes[style] ?? 17.0
    }
}

extension Font {
    static func scoreline(_ style: Font.TextStyle,
                          weight: ScorelineFont.Weight = .heavy,
                          width: ScorelineFont.Width = .standard) -> Font {
        .custom(ScorelineFont.name(weight: weight, width: width),
                size: ScorelineFont.baseSize(for: style), relativeTo: style)
    }

    static func scoreline(size: CGFloat,
                          weight: ScorelineFont.Weight = .heavy,
                          width: ScorelineFont.Width = .standard) -> Font {
        .custom(ScorelineFont.name(weight: weight, width: width), fixedSize: size)
    }
}
