import SwiftUI
import Observation

@MainActor
@Observable
final class AppModel {
    private(set) var paths: ProjectPaths?
    private(set) var schema: Schema = .placeholder
    private(set) var images: [URL] = []
    private(set) var labels: [String: [Box]] = [:]

    var currentIndex: Int = 0
    var currentClass: String?
    var selectedBoxID: UUID?
    var selection: Set<URL> = []

    static let productionModelName = "DJDXResultDetector.mlpackage"
    static let evalModelName = "DJDXResultDetector-eval.mlpackage"
    static let evalDetectorBaseName = "DJDXResultDetector-eval"

    private(set) var status: String = ""
    private(set) var loadError: String?
    var isAutoLabeling = false
    var isBuildingModel = false

    private var undoStacks: [String: [[Box]]] = [:]
    private let undoDepth = 30

    var currentImageURL: URL? {
        images.indices.contains(currentIndex) ? images[currentIndex] : nil
    }
    var currentImageName: String? { currentImageURL?.lastPathComponent }
    var currentBoxes: [Box] { currentImageName.map { labels[$0] ?? [] } ?? [] }

    var selectedBox: Box? {
        guard let id = selectedBoxID else { return nil }
        return currentBoxes.first { $0.id == id }
    }

    func labelCount(for url: URL) -> Int { labels[url.lastPathComponent]?.count ?? 0 }

    // MARK: - Loading

    func configure(root: URL) {
        let p = ProjectPaths(root: root)
        paths = p
        ProjectRootStore.save(root)
        reload()
    }

    func reload() {
        guard let p = paths else { return }
        loadError = nil
        do {
            schema = try SchemaLoader.load(from: p.schemaFile)
        } catch {
            loadError = error.localizedDescription
            schema = .placeholder
        }
        currentClass = schema.labelClasses.first
        images = SupportedImage.list(in: p.dataDir)
        let set = LabelStore.load(labelsFile: p.labelsFile, autoSeedFile: p.autoSeedFile)
        labels = set.byImage
        for url in images where labels[url.lastPathComponent] == nil {
            labels[url.lastPathComponent] = []
        }
        currentIndex = min(currentIndex, max(images.count - 1, 0))
        selectedBoxID = nil
        selection.removeAll()
        undoStacks.removeAll()
        if images.isEmpty {
            setStatus("No \(SupportedImage.extensions.sorted().joined(separator: "/")) images in \(p.dataDir.path)")
        } else {
            setStatus("Loaded \(images.count) images, \(labels.values.reduce(0) { $0 + $1.count }) boxes")
        }
    }

    // MARK: - Navigation

    func show(_ index: Int) {
        guard images.indices.contains(index) else { return }
        autosave()
        currentIndex = index
        selectedBoxID = nil
    }

    func next() { show(currentIndex + 1); syncSelectionToCurrent() }
    func prev() { show(currentIndex - 1); syncSelectionToCurrent() }

    private func syncSelectionToCurrent() {
        if let url = currentImageURL { selection = [url] }
    }

    // MARK: - Box mutation

    func setBoxes(_ boxes: [Box], pushUndo: Bool = true) {
        guard let name = currentImageName else { return }
        if pushUndo { pushUndoSnapshot(name) }
        labels[name] = boxes
    }

    func addBox(_ box: Box) {
        guard let name = currentImageName else { return }
        pushUndoSnapshot(name)
        labels[name, default: []].append(box.normalised())
        selectedBoxID = labels[name]?.last?.id
    }

    func updateBox(_ box: Box, pushUndo: Bool) {
        guard let name = currentImageName,
              let idx = labels[name]?.firstIndex(where: { $0.id == box.id }) else { return }
        if pushUndo { pushUndoSnapshot(name) }
        labels[name]?[idx] = box.normalised()
    }

    func deleteSelected() {
        guard let name = currentImageName, let id = selectedBoxID,
              let idx = labels[name]?.firstIndex(where: { $0.id == id }) else { return }
        pushUndoSnapshot(name)
        labels[name]?.remove(at: idx)
        selectedBoxID = nil
    }

    func clearSelectionLabels() {
        let urls = selectedImages
        guard !urls.isEmpty else { setStatus("Select images first"); return }
        for url in urls {
            let name = url.lastPathComponent
            if !(labels[name] ?? []).isEmpty {
                pushUndoSnapshot(name)
                labels[name] = []
            }
        }
        save()
        selectedBoxID = nil
        setStatus("Removed labels from \(urls.count) selected images")
    }

    func clearCurrentLabels() {
        guard let name = currentImageName, !(labels[name] ?? []).isEmpty else { return }
        pushUndoSnapshot(name)
        labels[name] = []
        selectedBoxID = nil
        setStatus("Removed all labels on \(name)")
    }

    func assignClassToSelection(_ cls: String) {
        currentClass = cls
        guard let box = selectedBox else { return }
        var b = box
        b.cls = cls
        updateBox(b, pushUndo: true)
    }

    func cycleSelectedClass() {
        guard let box = selectedBox else { return }
        let classes = schema.labelClasses
        let i = classes.firstIndex(of: box.cls) ?? -1
        var b = box
        b.cls = classes[(i + 1) % classes.count]
        updateBox(b, pushUndo: true)
    }

    // MARK: - Undo

    private func pushUndoSnapshot(_ name: String) {
        var stack = undoStacks[name] ?? []
        stack.append(labels[name] ?? [])
        if stack.count > undoDepth { stack.removeFirst(stack.count - undoDepth) }
        undoStacks[name] = stack
    }

    func undo() {
        guard let name = currentImageName, var stack = undoStacks[name], let prev = stack.popLast() else {
            setStatus("Nothing to undo")
            return
        }
        undoStacks[name] = stack
        labels[name] = prev
        selectedBoxID = nil
    }

    // MARK: - Saving

    func save() {
        guard let p = paths else { return }
        do {
            try LabelStore.save(LabelSet(byImage: labels), to: p.labelsFile)
            setStatus("Saved → \(p.labelsFile.lastPathComponent)")
        } catch {
            setStatus("Save failed: \(error.localizedDescription)")
        }
    }

    private func autosave() {
        guard let p = paths else { return }
        try? LabelStore.save(LabelSet(byImage: labels), to: p.labelsFile)
    }

    // Load labels from an arbitrary labels.json (replaces the working set).
    func importLabels(from url: URL) {
        guard let set = LabelStore.loadFile(url) else {
            setStatus("Could not read \(url.lastPathComponent)")
            return
        }
        labels = set.byImage
        for u in images where labels[u.lastPathComponent] == nil {
            labels[u.lastPathComponent] = []
        }
        selectedBoxID = nil
        undoStacks.removeAll()
        let total = labels.values.reduce(0) { $0 + $1.count }
        setStatus("Loaded \(total) boxes from \(url.lastPathComponent)")
    }

    // Wipe every label, in memory and on disk. Destructive; gate behind a prompt.
    func clearAllData() {
        guard let p = paths else { return }
        for key in labels.keys { labels[key] = [] }
        try? FileManager.default.removeItem(at: p.labelsFile)
        undoStacks.removeAll()
        selectedBoxID = nil
        setStatus("Cleared all labels and deleted \(p.labelsFile.lastPathComponent)")
    }

    // MARK: - CoreML model build

    // Train on every label, then export the detector into the *evaluation* slot
    // beside production. Promote it once the labels look good.
    func exportCoreMLModel() {
        guard let p = paths else { return }
        save()
        runPipeline([
            ("Preparing dataset", ["run", "python", "scripts/prepare_dataset.py", "--emit-classifier-crops"]),
            ("Training detector", ["run", "python", "scripts/train_detector.py"]),
            ("Exporting CoreML", ["run", "python", "scripts/export_coreml.py",
                                  "--detector-name", Self.evalDetectorBaseName]),
        ], cwd: p.trainingDir, success: "Evaluation model exported → Outputs/")
    }

    // Train a quick evaluation model on just the selected images' labels.
    func createEvalModelFromSelection() {
        guard let p = paths else { return }
        let urls = selectedImages
        guard !urls.isEmpty else { setStatus("Select images first"); return }
        var subset: [String: [Box]] = [:]
        for url in urls {
            let name = url.lastPathComponent
            subset[name] = labels[name] ?? []
        }
        let subsetFile = p.labelsDir.appending(path: "_eval_subset.json")
        do {
            try LabelStore.save(LabelSet(byImage: subset), to: subsetFile)
        } catch {
            setStatus("Could not stage selection: \(error.localizedDescription)")
            return
        }
        runPipeline([
            ("Preparing dataset", ["run", "python", "scripts/prepare_dataset.py",
                                   "--labels", "labels/_eval_subset.json"]),
            ("Training detector", ["run", "python", "scripts/train_detector.py"]),
            ("Exporting CoreML", ["run", "python", "scripts/export_coreml.py",
                                  "--only", "detector", "--detector-name", Self.evalDetectorBaseName]),
        ], cwd: p.trainingDir, success: "Evaluation model created from \(urls.count) images → Outputs/")
    }

    // Copy the evaluation model over the production one, so it backs
    // "Label current" / "Auto label all". Keeps the eval model for further work.
    func promoteEvalToProduction() {
        guard let p = paths, let eval = evalModelURL else { return }
        let prod = p.outputDir.appending(path: Self.productionModelName)
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: prod.path) { try fm.removeItem(at: prod) }
            try fm.copyItem(at: eval, to: prod)
            CoreMLPipeline.invalidateCache()
            setStatus("Promoted evaluation model → production")
        } catch {
            setStatus("Promote failed: \(error.localizedDescription)")
        }
    }

    private func runPipeline(_ steps: [(String, [String])], cwd: URL, success: String) {
        guard !isBuildingModel else { return }
        guard let uv = PythonTool.resolveUV() else {
            setStatus("`uv` not found — install from docs.astral.sh/uv")
            return
        }
        isBuildingModel = true
        setStatus("Building CoreML model… this can take several minutes")
        Task {
            for (label, args) in steps {
                setStatus("\(label)…")
                let code = await PythonTool.run(uv, args: args, cwd: cwd) { chunk in
                    Task { @MainActor in self.reportBuild(label, chunk) }
                }
                if code != 0 {
                    isBuildingModel = false
                    setStatus("Model build failed during “\(label)” (exit \(code))")
                    return
                }
            }
            isBuildingModel = false
            CoreMLPipeline.invalidateCache()
            setStatus(success)
        }
    }

    private func reportBuild(_ label: String, _ chunk: String) {
        let line = chunk.split(whereSeparator: \.isNewline).last.map(String.init) ?? chunk
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { status = "\(label): \(trimmed)" }
    }

    // MARK: - Auto-label

    // Prefer the trained CoreML detector; fall back to the rough Vision-OCR
    // heuristic only when the exported model isn't present.
    private var detectorModelURL: URL? {
        guard let p = paths else { return nil }
        let u = p.outputDir.appending(path: Self.productionModelName)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    var evalModelURL: URL? {
        guard let p = paths else { return nil }
        let u = p.outputDir.appending(path: Self.evalModelName)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }
    var hasEvalModel: Bool { evalModelURL != nil }
    var hasProductionModel: Bool { detectorModelURL != nil }

    var selectedImages: [URL] { images.filter { selection.contains($0) } }

    private nonisolated static func label(_ url: URL, model: URL?, schema: Schema) async -> [Box] {
        await Task.detached {
            if let model, let cg = ImageDecoder.load(url),
               let boxes = try? CoreMLPipeline.detect(cg, modelURL: model, schema: schema),
               !boxes.isEmpty {
                return boxes
            }
            return AutoLabel.boxes(from: OCR.recognize(url: url))
        }.value
    }

    // Detect with a specific model, no OCR fallback — so eval output reflects
    // the model alone.
    private nonisolated static func detectOnly(_ url: URL, model: URL, schema: Schema) async -> [Box] {
        await Task.detached {
            guard let cg = ImageDecoder.load(url) else { return [] }
            return (try? CoreMLPipeline.detect(cg, modelURL: model, schema: schema)) ?? []
        }.value
    }

    func labelSelectionUsingEvalModel() async {
        await labelSelection(with: evalModelURL, named: "eval")
    }

    func labelSelectionUsingProductionModel() async {
        await labelSelection(with: detectorModelURL, named: "production")
    }

    private func labelSelection(with model: URL?, named: String) async {
        guard let model, !isAutoLabeling else { return }
        let urls = selectedImages
        guard !urls.isEmpty else { setStatus("Select images first"); return }
        isAutoLabeling = true
        for (i, url) in urls.enumerated() {
            setStatus("Labelling \(i + 1)/\(urls.count) (\(named))…")
            labels[url.lastPathComponent] = await Self.detectOnly(url, model: model, schema: schema)
        }
        save()
        selectedBoxID = nil
        isAutoLabeling = false
        setStatus("Re-labelled \(urls.count) selected images (\(named) model)")
    }

    func autoLabelCurrent() async {
        guard let url = currentImageURL, !isAutoLabeling else { return }
        isAutoLabeling = true
        let usingModel = detectorModelURL != nil
        setStatus(usingModel ? "Detecting…" : "OCR…")
        let boxes = await Self.label(url, model: detectorModelURL, schema: schema)
        setBoxes(boxes)
        selectedBoxID = nil
        isAutoLabeling = false
        setStatus("Labelled \(boxes.count) boxes \(usingModel ? "(model)" : "(OCR)")")
    }

    func autoLabelAll() async {
        guard !isAutoLabeling, !images.isEmpty else { return }
        isAutoLabeling = true
        let model = detectorModelURL
        let usingModel = model != nil
        let urls = images
        for (i, url) in urls.enumerated() {
            setStatus("\(usingModel ? "Detecting" : "OCR") \(i + 1)/\(urls.count)…")
            labels[url.lastPathComponent] = await Self.label(url, model: model, schema: schema)
        }
        save()
        isAutoLabeling = false
        setStatus("Labelled all \(urls.count) images \(usingModel ? "(model)" : "(OCR)")")
    }

    // MARK: - Status

    func setStatus(_ msg: String) {
        let pos = images.isEmpty ? "" : "[\(currentIndex + 1)/\(images.count)] \(currentImageName ?? "") · "
        status = "\(pos)\(currentBoxes.count) boxes · class=\(currentClass ?? "—") · \(msg)"
    }
}
