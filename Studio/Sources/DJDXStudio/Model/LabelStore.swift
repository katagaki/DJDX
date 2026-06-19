import Foundation

enum LabelStore {
    static func load(labelsFile: URL, autoSeedFile: URL) -> LabelSet {
        for url in [labelsFile, autoSeedFile] {
            if let data = try? Data(contentsOf: url),
               let set = try? JSONDecoder().decode(LabelSet.self, from: data) {
                return set
            }
        }
        return LabelSet()
    }

    static func loadFile(_ url: URL) -> LabelSet? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LabelSet.self, from: data)
    }

    static func save(_ set: LabelSet, to url: URL) throws {
        try write(set, to: url)
    }

    static func loadClassification(_ url: URL) -> ClassificationLabelSet? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ClassificationLabelSet.self, from: data)
    }

    static func saveClassification(_ set: ClassificationLabelSet, to url: URL) throws {
        try write(set, to: url)
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }
}
