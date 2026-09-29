import Foundation
import SwiftSoup

struct SDVXInChart: Sendable, Hashable {
    var code: String
    var slot: String
    var title: String
    var level: Int

    var folder: String { String(code.prefix(2)) }

    var legacyPageURL: URL? {
        URL(string: "https://sdvx.in/\(folder)/\(code)\(slot).htm")
    }

    var viewerPageURL: URL? {
        URL(string: "https://sdvx.in/sdvx/_/viewer/viewer.php?id=\(code)\(slot)&folder=\(folder)")
    }

    var viewerDataURL: URL? {
        URL(string: "https://sdvx.in/sdvx/\(folder)/\(code)\(slot).json")
    }

    // Newer charts are only available in the viewer, which sdvx.in checks for by probing the chart JSON
    func resolvePageURL() async -> URL? {
        guard let viewerDataURL else { return legacyPageURL }
        var request = URLRequest(url: viewerDataURL)
        request.httpMethod = "HEAD"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let response = response as? HTTPURLResponse,
              response.statusCode == 200,
              response.mimeType?.contains("json") ?? false else {
            return legacyPageURL
        }
        return viewerPageURL
    }
}

struct SDVXInSong: Decodable {
    var id: String
    var title: String
    var levels: [String: String]

    private static let slots: [(key: String, slot: String)] = [
        ("nov", "n"), ("adv", "a"), ("exh", "e"), ("mxm", "m"), ("ult", "u")
    ]

    var charts: [SDVXInChart] {
        let digits = id.filter(\.isNumber)
        guard !digits.isEmpty else { return [] }
        let code = String((String(repeating: "0", count: 5) + digits).suffix(5))
        let title = ((try? Entities.unescape(title)) ?? title)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return [] }
        return Self.slots.compactMap { key, slot in
            // Levels prefixed with "_" have no chart page on sdvx.in
            guard let rawLevel = levels[key], !rawLevel.hasPrefix("_"),
                  let level = Self.level(from: rawLevel) else { return nil }
            return SDVXInChart(code: code, slot: slot, title: title, level: level)
        }
    }

    // Levels look like "15", "g19" or "183" (18.3); only the integer level is kept
    private static func level(from rawLevel: String) -> Int? {
        let digits = rawLevel.drop { !$0.isNumber }.prefix { $0.isNumber }
        guard let level = Int(digits.prefix(2)), level > 0 else { return nil }
        return level
    }
}
