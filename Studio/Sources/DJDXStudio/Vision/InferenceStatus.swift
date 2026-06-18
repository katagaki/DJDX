import Foundation

// Phase 3 has two halves: overlaying a Python-produced predictions.json (works
// today) and running the exported CoreML models natively (needs the
// .mlpackage artifacts, which only exist after export_coreml.py). This reports
// which exported models are present so the inspector can gate the live path.
struct ModelAvailability: Sendable {
    var detector: Bool
    var rank: Bool
    var clearType: Bool

    var anyMissing: Bool { !(detector && rank && clearType) }

    static func check(in outputDir: URL) -> ModelAvailability {
        let fm = FileManager.default
        func has(_ name: String) -> Bool {
            fm.fileExists(atPath: outputDir.appending(path: "\(name).mlpackage").path)
        }
        return ModelAvailability(
            detector: has("DJDXResultDetector"),
            rank: has("DJDXRankClassifier"),
            clearType: has("DJDXClearTypeClassifier"))
    }
}
