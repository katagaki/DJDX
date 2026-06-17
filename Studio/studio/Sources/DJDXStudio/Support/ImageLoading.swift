import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Supported input formats (decision Q4): the common iPhone-photo types.
enum SupportedImage {
    static let extensions: Set<String> = ["jpg", "jpeg", "heic"]

    static func isSupported(_ url: URL) -> Bool {
        extensions.contains(url.pathExtension.lowercased())
    }

    static func list(in directory: URL) -> [URL] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return entries
            .filter(isSupported)
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}

enum ImageDecoder {
    static func load(_ url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: false,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateImageAtIndex(src, 0, options as CFDictionary)
    }

    static func pixelSize(_ url: URL) -> CGSize? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return CGSize(width: w, height: h)
    }
}
