import Foundation
import Yams

// The parts of training/schema.yaml the app needs. schema.yaml stays the
// single source of truth (decision Q1); read with Yams, not duplicated.
struct Schema: Sendable, Equatable {
    var detectorClasses: [String]
    var rankClasses: [String]
    var clearTypeClasses: [String]
    var digitClasses: [String]
    var detectorImageSize: Int

    static let unlabeledText = "unlabeled_text"

    // Fallback hotkey pool for classes that aren't their own key: number row,
    // then QWERTY, then the home row (see AppModel.hotkeys).
    static let classHotkeyOrder = Array("1234567890qwertyuiopasdfghjkl")

    static let placeholder = Schema(
        detectorClasses: [], rankClasses: [], clearTypeClasses: [],
        digitClasses: [], detectorImageSize: 960
    )

    func classes(for source: ClassSource) -> [String] {
        switch source {
        case .detector: detectorClasses
        case .rank: rankClasses
        case .digit: digitClasses
        }
    }
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
            // Digit classes (digit_detector) may parse as Int if left unquoted in
            // YAML; coerce so both "0" and 0 land as the string "0".
            return list.compactMap { item -> String? in
                if let s = item as? String { return s.trimmingCharacters(in: .whitespaces) }
                if let i = item as? Int { return String(i) }
                return nil
            }
        }

        let imageSize = ((root["training"] as? [String: Any])?["detector"] as? [String: Any])?["image_size"] as? Int

        return Schema(
            detectorClasses: try classes("detector"),
            rankClasses: try classes("rank_classifier"),
            clearTypeClasses: try classes("clear_type_classifier"),
            digitClasses: try classes("digit_detector"),
            detectorImageSize: imageSize ?? 960
        )
    }
}
