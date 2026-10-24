import SwiftUI
import ImageIO

// Small, cached image thumbnail for sidebar rows. The crop workspaces (DJ Level,
// DigitDetector) list hundreds–thousands of tiny images; decoding a downscaled
// thumbnail (not the full image) and caching it keeps scrolling cheap.
enum ThumbnailLoader {
    // NSCache is internally thread-safe, so a shared instance is fine to touch
    // from the detached decode and the main-actor lookup. CGImage is a class.
    private nonisolated(unsafe) static let cache = NSCache<NSURL, CGImage>()

    static func cached(_ url: URL) -> CGImage? { cache.object(forKey: url as NSURL) }

    static func load(_ url: URL, maxPixel: Int) -> CGImage? {
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // honour EXIF orientation
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let img = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else {
            return nil
        }
        cache.setObject(img, forKey: url as NSURL)
        return img
    }
}

struct ThumbnailView: View {
    let url: URL
    var maxPixel: Int = 128

    @State private var image: CGImage?

    var body: some View {
        ZStack {
            if let image {
                Image(decorative: image, scale: 1, orientation: .up)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(.quaternary)
            }
        }
        .task(id: url) {
            if let hit = ThumbnailLoader.cached(url) { image = hit; return }
            let u = url, mp = maxPixel
            image = await Task.detached { ThumbnailLoader.load(u, maxPixel: mp) }.value
        }
    }
}
