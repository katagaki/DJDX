import Foundation

// On-disk layout, relative to the repo root. The Swift studio app lives at the
// root; Python training modules live under Training/; inputs/ and outputs/ are
// shared working dirs. Paths mirror Training/scripts/_common.py.
struct ProjectPaths: Equatable {
    let root: URL

    var inputsDir: URL { root.appending(path: "Inputs", directoryHint: .isDirectory) }
    var trainingDir: URL { root.appending(path: "Training", directoryHint: .isDirectory) }
    var schemaFile: URL { trainingDir.appending(path: "schema.yaml") }
    var labelsDir: URL { trainingDir.appending(path: "labels", directoryHint: .isDirectory) }
    var autoSeedFile: URL { labelsDir.appending(path: "auto_seed.json") }
    var outputDir: URL { root.appending(path: "Outputs", directoryHint: .isDirectory) }
    var predictionsFile: URL { outputDir.appending(path: "predictions.json") }
    var previewDir: URL { outputDir.appending(path: "label_preview", directoryHint: .isDirectory) }
    var modelsDir: URL { outputDir.appending(path: "models", directoryHint: .isDirectory) }
    // Reader-training crops sliced from Result Detector labels; the user moves
    // crops/DJLevels and crops/DigitDetector into the matching Inputs/ subfolders.
    var cropsDir: URL { outputDir.appending(path: "crops", directoryHint: .isDirectory) }

    // Per-workspace working dirs/files.
    func dataDir(_ c: WorkspaceConfig) -> URL {
        inputsDir.appending(path: c.inputSubdir, directoryHint: .isDirectory)
    }
    func labelsFile(_ c: WorkspaceConfig) -> URL { labelsDir.appending(path: c.labelsFileName) }
    func evalSubsetFile(_ c: WorkspaceConfig) -> URL {
        labelsDir.appending(path: c.evalSubsetFileName)
    }
    func modelURL(named name: String) -> URL { outputDir.appending(path: name) }

    var looksValid: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: inputsDir.path) && fm.fileExists(atPath: schemaFile.path)
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
