import CoreText
import SwiftUI

enum RadarlineFont {
    private static let registered: Void = {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls where url.lastPathComponent.hasPrefix("Radarline-") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    static func name(weight: ScorelineFont.Weight, width: ScorelineFont.Width) -> String {
        _ = registered
        return "Radarline-\(width.rawValue)\(weight.rawValue)"
    }
}

extension Font {
    static func radarline(_ style: Font.TextStyle,
                          weight: ScorelineFont.Weight = .heavy,
                          width: ScorelineFont.Width = .standard) -> Font {
        .custom(RadarlineFont.name(weight: weight, width: width),
                size: ScorelineFont.baseSize(for: style), relativeTo: style)
    }

    static func radarline(size: CGFloat,
                          weight: ScorelineFont.Weight = .heavy,
                          width: ScorelineFont.Width = .standard) -> Font {
        .custom(RadarlineFont.name(weight: weight, width: width), fixedSize: size)
    }
}
