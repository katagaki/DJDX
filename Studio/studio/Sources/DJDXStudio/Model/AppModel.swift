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

    private(set) var status: String = ""
    private(set) var loadError: String?
    var isAutoLabeling = false

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

    func next() { show(currentIndex + 1) }
    func prev() { show(currentIndex - 1) }

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

    // MARK: - Auto-label (native Vision)

    func autoLabelCurrent() async {
        guard let url = currentImageURL, !isAutoLabeling else { return }
        isAutoLabeling = true
        setStatus("OCR…")
        let boxes = await Task.detached { AutoLabel.boxes(from: OCR.recognize(url: url)) }.value
        setBoxes(boxes)
        selectedBoxID = nil
        isAutoLabeling = false
        setStatus("Auto-labelled \(boxes.count) regions")
    }

    func autoLabelAll() async {
        guard !isAutoLabeling, !images.isEmpty else { return }
        isAutoLabeling = true
        let urls = images
        for (i, url) in urls.enumerated() {
            setStatus("OCR \(i + 1)/\(urls.count)…")
            let name = url.lastPathComponent
            let boxes = await Task.detached { AutoLabel.boxes(from: OCR.recognize(url: url)) }.value
            labels[name] = boxes
        }
        save()
        isAutoLabeling = false
        setStatus("Auto-labelled all \(urls.count) images")
    }

    // MARK: - Status

    func setStatus(_ msg: String) {
        let pos = images.isEmpty ? "" : "[\(currentIndex + 1)/\(images.count)] \(currentImageName ?? "") · "
        status = "\(pos)\(currentBoxes.count) boxes · class=\(currentClass ?? "—") · \(msg)"
    }
}
