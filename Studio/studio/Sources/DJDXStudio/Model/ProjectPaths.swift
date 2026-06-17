import Foundation

// On-disk layout of a project, relative to a root containing data/ and
// training/. Paths mirror training/scripts/_common.py.
struct ProjectPaths: Equatable {
    let root: URL

    var dataDir: URL { root.appending(path: "data", directoryHint: .isDirectory) }
    var trainingDir: URL { root.appending(path: "training", directoryHint: .isDirectory) }
    var schemaFile: URL { trainingDir.appending(path: "schema.yaml") }
    var labelsDir: URL { trainingDir.appending(path: "labels", directoryHint: .isDirectory) }
    var labelsFile: URL { labelsDir.appending(path: "labels.json") }
    var autoSeedFile: URL { labelsDir.appending(path: "auto_seed.json") }
    var outputDir: URL { trainingDir.appending(path: "output", directoryHint: .isDirectory) }
    var predictionsFile: URL { outputDir.appending(path: "predictions.json") }
    var previewDir: URL { outputDir.appending(path: "label_preview", directoryHint: .isDirectory) }
    var modelsDir: URL { trainingDir.appending(path: "models", directoryHint: .isDirectory) }

    var looksValid: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: dataDir.path) && fm.fileExists(atPath: schemaFile.path)
    }
}

enum ProjectRootStore {
    private static let pathKey = "projectRootPath"

    static var fallback: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appending(path: "Developer/DJDX PEAK", directoryHint: .isDirectory)
    }

    static func load() -> URL? {
        guard let path = UserDefaults.standard.string(forKey: pathKey) else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static func save(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: pathKey)
    }
}
