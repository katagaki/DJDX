import SwiftUI
import AppKit
import Observation

@MainActor
@Observable
final class AppModel {
    private(set) var paths: ProjectPaths?
    private(set) var schema: Schema = .placeholder
    private(set) var images: [URL] = []
    private(set) var labels: [String: [Box]] = [:]

    // Active workspace (Result Detector / DJ Level / DigitDetector). Drives data dir,
    // label file + codec, class set, model names, and the build pipeline.
    private(set) var config: WorkspaceConfig = .resultDetector
    var workspace: Workspace { config.workspace }

    // Classes for the active workspace's palette/hotkeys. The "unlabeled_text"
    // sink only exists for the Result Detector.
    var labelClasses: [String] {
        let base = schema.classes(for: config.classSource)
        return config.appendUnlabeled ? base + [Schema.unlabeledText] : base
    }

    // Hotkey assignment for the active workspace. When the workspace uses literal
    // hotkeys (DigitDetector), a single-character class name is its own key so
    // "1"→"1", "9"→"9"; everything else takes the next free key from the
    // keyboard-order pool (the historical number/QWERTY/home-row run).
    struct Hotkeys {
        var keyForClass: [String: String] = [:]
        var classForKey: [String: String] = [:]
    }

    var hotkeys: Hotkeys {
        var map = Hotkeys()
        var used = Set<Character>()
        func bind(_ cls: String, _ ch: Character) {
            used.insert(ch)
            map.keyForClass[cls] = String(ch)
            map.classForKey[String(ch)] = cls
        }
        if config.literalHotkeys {
            for cls in labelClasses where cls.count == 1 {
                if let ch = cls.lowercased().first, !used.contains(ch) { bind(cls, ch) }
            }
        }
        var pool = Schema.classHotkeyOrder.makeIterator()
        for cls in labelClasses where map.keyForClass[cls] == nil {
            while let ch = pool.next() {
                if !used.contains(ch) { bind(cls, ch); break }
            }
        }
        return map
    }

    var currentIndex: Int = 0
    var currentClass: String?
    var selectedBoxID: UUID?
    var selection: Set<URL> = []

    private(set) var status: String = ""
    private(set) var loadError: String?
    var isAutoLabeling = false
    var isBuildingModel = false
    var isExportingCrops = false

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

    // Sidebar summaries. DJ Level (classification) keeps its rank in a single
    // full-frame box; the DigitDetector keeps one box per glyph, read
    // left-to-right by ascending x. Both read live from `labels`.
    func classificationTag(for url: URL) -> String? {
        labels[url.lastPathComponent]?.first?.cls
    }

    func digitReading(for url: URL) -> String {
        let boxes = labels[url.lastPathComponent] ?? []
        return boxes.sorted { $0.x < $1.x }.map(Self.digitGlyph).joined()
    }

    private static func digitGlyph(_ box: Box) -> String {
        switch box.cls {
        case "plus": return "+"
        case "minus": return "-"
        default: return box.cls   // "0"…"9"
        }
    }

    // MARK: - Loading

    func configure(root: URL) {
        let p = ProjectPaths(root: root)
        paths = p
        ProjectRootStore.save(root)
        reload()
    }

    // Switch the active workspace, persisting the outgoing one's labels first so
    // nothing is lost. reload() resets index/selection/undo for the new set.
    func switchWorkspace(_ w: Workspace) {
        guard w != config.workspace else { return }
        autosave()
        config = .config(for: w)
        currentIndex = 0
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
        currentClass = labelClasses.first
        images = SupportedImage.list(in: p.dataDir(config))
        labels = loadLabels(p)
        for url in images where labels[url.lastPathComponent] == nil {
            labels[url.lastPathComponent] = []
        }
        // DJ Level: group the list by rank (F→AAA, unlabeled last) so a mislabel
        // jumps out — a glyph sitting in the wrong rank group is obvious. Sorted
        // once on entry (re-entering the workspace re-sorts) so rows stay put
        // while labelling. Other workspaces keep filename order.
        if config.workspace == .djLevel {
            images.sort(by: rankThenName)
        }
        currentIndex = min(currentIndex, max(images.count - 1, 0))
        selectedBoxID = nil
        selection.removeAll()
        undoStacks.removeAll()
        if images.isEmpty {
            setStatus("No \(SupportedImage.extensions.sorted().joined(separator: "/")) images in Inputs/\(config.inputSubdir)/")
        } else {
            let unit = config.labelKind == .classification ? "tags" : "boxes"
            setStatus("Loaded \(images.count) images, \(labels.values.reduce(0) { $0 + $1.count }) \(unit)")
        }
    }

    // Read the active workspace's labels into the uniform [name: [Box]] form.
    // Classification labels become a single full-frame box per image.
    private func loadLabels(_ p: ProjectPaths) -> [String: [Box]] {
        let file = p.labelsFile(config)
        switch config.labelKind {
        case .classification:
            let set = LabelStore.loadClassification(file) ?? ClassificationLabelSet()
            return set.byImage.mapValues { [Box(cls: $0, x: 0, y: 0, w: 1, h: 1)] }
        case .bbox:
            // Only the Result Detector has an OCR auto-seed to fall back to.
            if config.workspace == .resultDetector {
                return LabelStore.load(labelsFile: file, autoSeedFile: p.autoSeedFile).byImage
            }
            return (LabelStore.loadFile(file) ?? LabelSet()).byImage
        }
    }

    // Sort key for the DJ Level list: position in the schema's rank list
    // (F=0 … AAA=last), with unlabeled/unknown crops sorted after every rank.
    private func rankSortIndex(for url: URL) -> Int {
        guard let tag = labels[url.lastPathComponent]?.first?.cls,
              let i = schema.rankClasses.firstIndex(of: tag) else {
            return schema.rankClasses.count
        }
        return i
    }

    private func rankThenName(_ a: URL, _ b: URL) -> Bool {
        let ra = rankSortIndex(for: a), rb = rankSortIndex(for: b)
        if ra != rb { return ra < rb }
        return a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
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

    // DJ Level (classification): the whole crop carries one class, stored as a
    // single full-frame box so the rest of the model stays box-shaped.
    var currentTag: String? { currentBoxes.first?.cls }

    func tagCurrent(_ cls: String, advance: Bool = true) {
        currentClass = cls
        setBoxes([Box(cls: cls, x: 0, y: 0, w: 1, h: 1)])
        selectedBoxID = nil
        if advance { next() }
    }

    func cycleSelectedClass() {
        guard let box = selectedBox else { return }
        let classes = labelClasses
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
            try persistLabels(to: p.labelsFile(config))
            setStatus("Saved → \(config.labelsFileName)")
        } catch {
            setStatus("Save failed: \(error.localizedDescription)")
        }
    }

    private func autosave() {
        guard let p = paths else { return }
        try? persistLabels(to: p.labelsFile(config))
    }

    // Persist in the active workspace's on-disk shape. Classification writes
    // {name: class}, dropping unlabelled images; bbox writes {name: [box]}.
    private func persistLabels(to url: URL) throws {
        switch config.labelKind {
        case .classification:
            let byImage = labels.compactMapValues { $0.first?.cls }
            try LabelStore.saveClassification(ClassificationLabelSet(byImage: byImage), to: url)
        case .bbox:
            try LabelStore.save(LabelSet(byImage: labels), to: url)
        }
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

    // Wipe every label for the active workspace, in memory and on disk.
    // Destructive; gate behind a prompt.
    func clearAllData() {
        guard let p = paths else { return }
        for key in labels.keys { labels[key] = [] }
        try? FileManager.default.removeItem(at: p.labelsFile(config))
        undoStacks.removeAll()
        selectedBoxID = nil
        setStatus("Cleared all \(workspace.title) labels and deleted \(config.labelsFileName)")
    }

    // MARK: - CoreML model build

    // Train on every label of the active workspace, then export into the
    // *evaluation* slot beside production. Promote it once it looks good.
    func exportCoreMLModel() {
        guard let p = paths else { return }
        save()
        runPipeline(config.exportSteps, cwd: p.trainingDir,
                    success: "\(workspace.title) evaluation model exported → Outputs/")
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
        do {
            try stageSubset(subset, to: p.evalSubsetFile(config))
        } catch {
            setStatus("Could not stage selection: \(error.localizedDescription)")
            return
        }
        runPipeline(config.evalSteps, cwd: p.trainingDir,
                    success: "\(workspace.title) evaluation model from \(urls.count) images → Outputs/")
    }

    // Write a selection subset in the active workspace's on-disk shape.
    private func stageSubset(_ subset: [String: [Box]], to url: URL) throws {
        switch config.labelKind {
        case .classification:
            try LabelStore.saveClassification(
                ClassificationLabelSet(byImage: subset.compactMapValues { $0.first?.cls }), to: url)
        case .bbox:
            try LabelStore.save(LabelSet(byImage: subset), to: url)
        }
    }

    // Re-save the evaluation model into the production slot so it backs
    // "Label current" / "Auto label all". Goes through promote_coreml.py rather
    // than a plain file copy so the embedded CoreML description (MLModelDescription)
    // is re-stamped to drop the "-eval" staging suffix; the AGPL-3.0 license and
    // class metadata are preserved. Keeps the eval model for further work.
    func promoteEvalToProduction() {
        guard let p = paths, hasEvalModel else { return }
        guard !isBuildingModel else { return }
        guard let uv = PythonTool.resolveUV() else {
            setStatus("`uv` not found — install from docs.astral.sh/uv")
            return
        }
        let evalBase = (config.evalModelName as NSString).deletingPathExtension
        let prodBase = (config.productionModelName as NSString).deletingPathExtension
        let args = ["run", "python", "scripts/promote_coreml.py",
                    "--eval-name", evalBase, "--prod-name", prodBase]
        isBuildingModel = true
        setStatus("Promoting \(workspace.title) evaluation model → production…")
        Task {
            let code = await PythonTool.run(uv, args: args, cwd: p.trainingDir) { chunk in
                Task { @MainActor in self.reportBuild("Promote", chunk) }
            }
            isBuildingModel = false
            if code == 0 {
                CoreMLPipeline.invalidateCache()
                setStatus("Promoted \(workspace.title) evaluation model → production")
            } else {
                setStatus("Promote failed (exit \(code))")
            }
        }
    }

    private func runPipeline(_ steps: [PipelineStep], cwd: URL, success: String) {
        guard !isBuildingModel else { return }
        guard let uv = PythonTool.resolveUV() else {
            setStatus("`uv` not found — install from docs.astral.sh/uv")
            return
        }
        isBuildingModel = true
        setStatus("Building CoreML model… this can take several minutes")
        Task {
            for step in steps {
                setStatus("\(step.label)…")
                let code = await PythonTool.run(uv, args: step.args, cwd: cwd) { chunk in
                    Task { @MainActor in self.reportBuild(step.label, chunk) }
                }
                if code != 0 {
                    isBuildingModel = false
                    setStatus("Model build failed during “\(step.label)” (exit \(code))")
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

    // MARK: - Reader crops

    // Slice the DJ-level glyphs and numeric fields out of the labelled result
    // screens into Outputs/crops/{DJLevels,DigitDetector}/, ready to be moved
    // into Inputs/DJLevels and Inputs/DigitDetector and labelled in those
    // workspaces. Always reads the saved Result Detector labels regardless of
    // the active workspace; flushes in-flight edits first when it owns them.
    // The native equivalent of prepare_dataset.py --emit-crops-to-outputs.
    @discardableResult
    func exportReaderCrops() async -> Bool {
        guard let p = paths, !isExportingCrops else { return false }
        if config.workspace == .resultDetector { save() }
        let cfg = WorkspaceConfig.resultDetector
        guard let set = LabelStore.loadFile(p.labelsFile(cfg)) else {
            setStatus("No \(cfg.labelsFileName) yet — label some result screens first")
            return false
        }
        let byImage = set.byImage
        let resultsDir = p.dataDir(cfg)
        let cropsDir = p.cropsDir
        isExportingCrops = true
        setStatus("Cropping DJ Level + digit regions…")
        let outcome = await Task.detached {
            CropExport.exportReaderCrops(labels: byImage, resultsDir: resultsDir, cropsDir: cropsDir)
        }.value
        isExportingCrops = false
        switch outcome {
        case .success(let s):
            let missing = s.missingImages > 0 ? " · \(s.missingImages) photos missing" : ""
            setStatus("Cropped \(s.djLevels) DJ Level + \(s.digits) digit regions from "
                      + "\(s.images) screens → Outputs/crops/\(missing)")
            NSWorkspace.shared.activateFileViewerSelecting([cropsDir])
            return true
        case .failure(let why):
            setStatus("Crop failed: \(why)")
            return false
        }
    }

    // MARK: - Auto-label

    // The active workspace's production / evaluation model in Outputs/, if present.
    private var productionModelURL: URL? {
        guard let p = paths else { return nil }
        let u = p.modelURL(named: config.productionModelName)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    var evalModelURL: URL? {
        guard let p = paths else { return nil }
        let u = p.modelURL(named: config.evalModelName)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }
    var hasEvalModel: Bool { evalModelURL != nil }
    var hasProductionModel: Bool { productionModelURL != nil }

    // Only the Result Detector has a Vision-OCR fallback for unmodelled images.
    private var allowsOCRFallback: Bool { config.workspace == .resultDetector }

    var selectedImages: [URL] { images.filter { selection.contains($0) } }

    // Run the active workspace's model on one image → labels in the uniform box
    // form. Classification yields a single full-frame box; bbox yields detections
    // (with the Result-Detector post-process / OCR fallback when enabled).
    private nonisolated static func infer(
        _ url: URL, model: URL?, kind: LabelKind, postProcess: Bool,
        classes: [String], schema: Schema, allowOCR: Bool
    ) async -> [Box] {
        await Task.detached {
            func ocr() -> [Box] { allowOCR ? AutoLabel.boxes(from: OCR.recognize(url: url)) : [] }
            guard let model, let cg = ImageDecoder.load(url) else { return ocr() }
            switch kind {
            case .classification:
                if let result = try? CoreMLPipeline.classify(cg, modelURL: model, classes: classes) {
                    return [Box(cls: result.label, x: 0, y: 0, w: 1, h: 1, conf: result.confidence)]
                }
                return []   // no OCR equivalent for a glyph classifier
            case .bbox:
                if let boxes = try? CoreMLPipeline.detect(
                    cg, modelURL: model, schema: schema, postProcess: postProcess), !boxes.isEmpty {
                    return boxes
                }
                return ocr()
            }
        }.value
    }

    private func infer(_ url: URL, model: URL?, allowOCR: Bool) async -> [Box] {
        await Self.infer(url, model: model, kind: config.labelKind,
                         postProcess: config.usesPostProcess, classes: labelClasses,
                         schema: schema, allowOCR: allowOCR)
    }

    private var labelNoun: String { config.labelKind == .classification ? "tags" : "boxes" }

    func labelSelectionUsingEvalModel() async {
        await labelSelection(with: evalModelURL, named: "eval")
    }

    func labelSelectionUsingProductionModel() async {
        await labelSelection(with: productionModelURL, named: "production")
    }

    // Re-label with a specific model, no OCR fallback — output reflects the model alone.
    private func labelSelection(with model: URL?, named: String) async {
        guard let model, !isAutoLabeling else { return }
        let urls = selectedImages
        guard !urls.isEmpty else { setStatus("Select images first"); return }
        isAutoLabeling = true
        for (i, url) in urls.enumerated() {
            setStatus("Labelling \(i + 1)/\(urls.count) (\(named))…")
            labels[url.lastPathComponent] = await infer(url, model: model, allowOCR: false)
        }
        save()
        selectedBoxID = nil
        isAutoLabeling = false
        setStatus("Re-labelled \(urls.count) selected images (\(named) model)")
    }

    func autoLabelCurrent() async {
        guard let url = currentImageURL, !isAutoLabeling else { return }
        let model = productionModelURL
        guard model != nil || allowsOCRFallback else {
            setStatus("No \(workspace.title) model yet — export one first")
            return
        }
        isAutoLabeling = true
        setStatus(model != nil ? "Inferring…" : "OCR…")
        let boxes = await infer(url, model: model, allowOCR: allowsOCRFallback)
        setBoxes(boxes)
        selectedBoxID = nil
        isAutoLabeling = false
        setStatus("Labelled \(boxes.count) \(labelNoun) \(model != nil ? "(model)" : "(OCR)")")
    }

    func autoLabelAll() async {
        guard !isAutoLabeling, !images.isEmpty else { return }
        let model = productionModelURL
        guard model != nil || allowsOCRFallback else {
            setStatus("No \(workspace.title) model yet — export one first")
            return
        }
        isAutoLabeling = true
        let usingModel = model != nil
        let urls = images
        for (i, url) in urls.enumerated() {
            setStatus("\(usingModel ? "Inferring" : "OCR") \(i + 1)/\(urls.count)…")
            labels[url.lastPathComponent] = await infer(url, model: model, allowOCR: allowsOCRFallback)
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
