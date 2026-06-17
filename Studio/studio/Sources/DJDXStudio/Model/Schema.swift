import Foundation
import Yams

// The parts of training/schema.yaml the app needs. schema.yaml stays the
// single source of truth (decision Q1); read with Yams, not duplicated.
struct Schema: Sendable, Equatable {
    var detectorClasses: [String]
    var rankClasses: [String]
    var clearTypeClasses: [String]
    var detectorImageSize: Int

    static let unlabeledText = "unlabeled_text"

    var labelClasses: [String] { detectorClasses + [Self.unlabeledText] }

    static let placeholder = Schema(
        detectorClasses: [], rankClasses: [], clearTypeClasses: [], detectorImageSize: 960
    )
}

enum SchemaLoader {
    enum LoadError: LocalizedError {
        case unreadable(String)
        case malformed(String)

        var errorDescription: String? {
            switch self {
            case .unreadable(let p): "Could not read schema.yaml at \(p)"
            case .malformed(let why): "schema.yaml is malformed: \(why)"
            }
        }
    }

    static func load(from url: URL) throws -> Schema {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw LoadError.unreadable(url.path)
        }
        guard let root = try Yams.load(yaml: text) as? [String: Any] else {
            throw LoadError.malformed("top level is not a mapping")
        }

        func classes(_ section: String) throws -> [String] {
            guard let sec = root[section] as? [String: Any],
                  let list = sec["classes"] as? [Any] else {
                throw LoadError.malformed("missing \(section).classes")
            }
            return list.compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespaces) }
        }

        let imageSize = ((root["training"] as? [String: Any])?["detector"] as? [String: Any])?["image_size"] as? Int

        return Schema(
            detectorClasses: try classes("detector"),
            rankClasses: try classes("rank_classifier"),
            clearTypeClasses: try classes("clear_type_classifier"),
            detectorImageSize: imageSize ?? 960
        )
    }
}
