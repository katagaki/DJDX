import Foundation

// What the user is labelling in a given mode determines the editor and the
// on-disk label shape.
enum LabelKind: Equatable, Sendable {
    case bbox            // draw class-tagged boxes (Result Detector, DigitDetector)
    case classification  // tag the whole image with one class (DJ Level)
}

// Which schema class list a workspace labels against. (A plain enum rather than
// a KeyPath<Schema,…> so WorkspaceConfig can be Sendable.)
enum ClassSource: Sendable {
    case detector, rank, digit
}

// A top-level workspace = one training target. Each maps to its own Inputs
// subfolder, label file, class set, model pair, and training pipeline.
enum Workspace: String, CaseIterable, Identifiable, Equatable, Sendable {
    case resultDetector
    case djLevel
    case digitDetector

    var id: String { rawValue }

    var title: String {
        switch self {
        case .resultDetector: "Result Detector"
        case .djLevel: "DJ Level"
        case .digitDetector: "DigitDetector"
        }
    }
}

// One step of a build pipeline: a human label + the args handed to `uv`
// (first element is always "run", i.e. `uv run python scripts/…`).
struct PipelineStep: Sendable {
    let label: String
    let args: [String]
}

// Everything that differs between workspaces, pushed into a plain value so the
// single AppModel can switch behaviour without branching everywhere.
struct WorkspaceConfig: Sendable {
    let workspace: Workspace
    let labelKind: LabelKind
    let inputSubdir: String                       // Inputs/<inputSubdir>/
    let labelsFileName: String                    // labels/<labelsFileName>
    let evalSubsetFileName: String                // labels/<…> staged from a selection
    let classSource: ClassSource
    let appendUnlabeled: Bool                      // add the "unlabeled_text" sink class
    let usesPostProcess: Bool                      // Result-Detector-specific NMS / filters
    let literalHotkeys: Bool                       // single-char class names are their own key
    let productionModelName: String                // .mlpackage in Outputs/
    let evalModelName: String                      // staged-beside-production .mlpackage
    let exportSteps: [PipelineStep]                // train on all labels → eval model
    let evalSteps: [PipelineStep]                  // train on a selection subset → eval model

    var workspaceValue: Workspace { workspace }
}

extension WorkspaceConfig {
    static let resultDetector = WorkspaceConfig(
        workspace: .resultDetector,
        labelKind: .bbox,
        inputSubdir: "Results",
        labelsFileName: "labels.json",
        evalSubsetFileName: "_results_eval_subset.json",
        classSource: .detector,
        appendUnlabeled: true,
        usesPostProcess: true,
        literalHotkeys: false,
        productionModelName: "DJDXResultDetector.mlpackage",
        evalModelName: "DJDXResultDetector-eval.mlpackage",
        exportSteps: [
            PipelineStep(label: "Preparing dataset",
                         args: ["run", "python", "scripts/prepare_dataset.py",
                                "--target", "results", "--emit-crops-to-outputs"]),
            PipelineStep(label: "Training detector",
                         args: ["run", "python", "scripts/train_detector.py", "--target", "results"]),
            PipelineStep(label: "Exporting CoreML",
                         args: ["run", "python", "scripts/export_coreml.py",
                                "--only", "detector", "--detector-name", "DJDXResultDetector-eval"]),
        ],
        evalSteps: [
            PipelineStep(label: "Preparing dataset",
                         args: ["run", "python", "scripts/prepare_dataset.py", "--target", "results",
                                "--labels", "labels/_results_eval_subset.json"]),
            PipelineStep(label: "Training detector",
                         args: ["run", "python", "scripts/train_detector.py", "--target", "results"]),
            PipelineStep(label: "Exporting CoreML",
                         args: ["run", "python", "scripts/export_coreml.py",
                                "--only", "detector", "--detector-name", "DJDXResultDetector-eval"]),
        ]
    )

    static let djLevel = WorkspaceConfig(
        workspace: .djLevel,
        labelKind: .classification,
        inputSubdir: "DJLevels",
        labelsFileName: "djlevel_labels.json",
        evalSubsetFileName: "_djlevel_eval_subset.json",
        classSource: .rank,
        appendUnlabeled: false,
        usesPostProcess: false,
        literalHotkeys: false,
        productionModelName: "DJDXRankClassifier.mlpackage",
        evalModelName: "DJDXRankClassifier-eval.mlpackage",
        exportSteps: [
            PipelineStep(label: "Preparing dataset",
                         args: ["run", "python", "scripts/prepare_djlevel_dataset.py"]),
            PipelineStep(label: "Training classifier",
                         args: ["run", "python", "scripts/train_rank_classifier.py", "--target", "rank"]),
            PipelineStep(label: "Exporting CoreML",
                         args: ["run", "python", "scripts/export_coreml.py",
                                "--only", "rank", "--rank-name", "DJDXRankClassifier-eval"]),
        ],
        evalSteps: [
            PipelineStep(label: "Preparing dataset",
                         args: ["run", "python", "scripts/prepare_djlevel_dataset.py",
                                "--labels", "labels/_djlevel_eval_subset.json"]),
            PipelineStep(label: "Training classifier",
                         args: ["run", "python", "scripts/train_rank_classifier.py", "--target", "rank"]),
            PipelineStep(label: "Exporting CoreML",
                         args: ["run", "python", "scripts/export_coreml.py",
                                "--only", "rank", "--rank-name", "DJDXRankClassifier-eval"]),
        ]
    )

    static let digitDetector = WorkspaceConfig(
        workspace: .digitDetector,
        labelKind: .bbox,
        inputSubdir: "DigitDetector",
        labelsFileName: "digit_labels.json",
        evalSubsetFileName: "_digit_eval_subset.json",
        classSource: .digit,
        appendUnlabeled: false,
        usesPostProcess: false,
        literalHotkeys: true,
        productionModelName: "DJDXDigitsDetector.mlpackage",
        evalModelName: "DJDXDigitsDetector-eval.mlpackage",
        exportSteps: [
            PipelineStep(label: "Preparing dataset",
                         args: ["run", "python", "scripts/prepare_dataset.py", "--target", "digits"]),
            PipelineStep(label: "Training detector",
                         args: ["run", "python", "scripts/train_detector.py", "--target", "digits"]),
            PipelineStep(label: "Exporting CoreML",
                         args: ["run", "python", "scripts/export_coreml.py",
                                "--only", "digits", "--digits-name", "DJDXDigitsDetector-eval"]),
        ],
        evalSteps: [
            PipelineStep(label: "Preparing dataset",
                         args: ["run", "python", "scripts/prepare_dataset.py", "--target", "digits",
                                "--labels", "labels/_digit_eval_subset.json"]),
            PipelineStep(label: "Training detector",
                         args: ["run", "python", "scripts/train_detector.py", "--target", "digits"]),
            PipelineStep(label: "Exporting CoreML",
                         args: ["run", "python", "scripts/export_coreml.py",
                                "--only", "digits", "--digits-name", "DJDXDigitsDetector-eval"]),
        ]
    )

    static let all: [WorkspaceConfig] = [.resultDetector, .djLevel, .digitDetector]

    static func config(for workspace: Workspace) -> WorkspaceConfig {
        all.first { $0.workspace == workspace } ?? .resultDetector
    }
}
