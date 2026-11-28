import CoreText
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum PlaylineFont {
    private static let registered: Void = {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls where url.lastPathComponent.hasPrefix("Playline-") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    static func name(weight: ScorelineFont.Weight, width: ScorelineFont.Width) -> String {
        _ = registered
        return "Playline-\(width.rawValue)\(weight.rawValue)"
    }

    private static func fallbackName(for weight: ScorelineFont.Weight) -> String {
        switch weight {
        case .regular: "HiraginoSans-W5"
        case .medium: "HiraginoSans-W6"
        case .bold: "HiraginoSans-W7"
        case .heavy: "HiraginoSans-W8"
        }
    }

    static func ctFont(size: CGFloat,
                       weight: ScorelineFont.Weight,
                       width: ScorelineFont.Width) -> CTFont {
        let fallback = CTFontDescriptorCreateWithNameAndSize(fallbackName(for: weight) as CFString, size)
        let attributes: [CFString: Any] = [
            kCTFontNameAttribute: name(weight: weight, width: width),
            kCTFontCascadeListAttribute: [fallback]
        ]
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }

    static func scaledSize(for style: Font.TextStyle) -> CGFloat {
        let base = ScorelineFont.baseSize(for: style)
        #if canImport(UIKit)
        return UIFontMetrics(forTextStyle: uiTextStyle(for: style)).scaledValue(for: base)
        #else
        return base
        #endif
    }

    #if canImport(UIKit)
    private static func uiTextStyle(for style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }
    #endif
}

extension Font {
    static func playline(_ style: Font.TextStyle,
                         weight: ScorelineFont.Weight = .heavy,
                         width: ScorelineFont.Width = .standard) -> Font {
        Font(PlaylineFont.ctFont(size: PlaylineFont.scaledSize(for: style), weight: weight, width: width))
    }

    static func playline(size: CGFloat,
                         weight: ScorelineFont.Weight = .heavy,
                         width: ScorelineFont.Width = .standard) -> Font {
        Font(PlaylineFont.ctFont(size: size, weight: weight, width: width))
    }
}
