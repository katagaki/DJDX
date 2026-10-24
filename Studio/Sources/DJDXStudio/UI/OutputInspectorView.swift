import SwiftUI

struct OutputInspectorView: View {
    @Environment(AppModel.self) private var model

    @State private var cgImage: CGImage?
    @State private var pixelSize: CGSize = .zero
    @State private var predictions: [Box] = []
    @State private var source: Source = .labels
    @State private var note: String = ""

    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var containerSize: CGSize = .zero
    @GestureState private var gestureZoom: CGFloat = 1
    @GestureState private var gesturePan: CGSize = .zero

    private var effectiveZoom: CGFloat { Zoom.clamp(zoom * gestureZoom) }
    private var effectivePan: CGSize {
        CGSize(width: pan.width + gesturePan.width, height: pan.height + gesturePan.height)
    }

    enum Source: String, CaseIterable, Identifiable {
        case labels = "labels.json"
        case predictions = "predictions.json"
        case coreml = "CoreML (live)"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 8) {
            header
            GeometryReader { geo in
                let geom = EditorGeometry(container: geo.size, imagePixelSize: pixelSize,
                                          zoom: effectiveZoom, pan: effectivePan)
                ZStack {
                    Color(nsColor: .underPageBackgroundColor)
                    if let cgImage {
                        Image(decorative: cgImage, scale: 1, orientation: .up)
                            .resizable()
                            .frame(width: geom.displaySize.width, height: geom.displaySize.height)
                            .position(x: geom.offset.x + geom.displaySize.width / 2,
                                      y: geom.offset.y + geom.displaySize.height / 2)
                        Canvas { ctx, _ in
                            for box in boxesToShow {
                                let rect = geom.rect(for: box)
                                let color = ClassColor.color(for: box.cls)
                                ctx.stroke(Path(rect), with: .color(color), lineWidth: 2)
                                var tag = box.cls
                                if let c = box.conf { tag += String(format: " %.2f", c) }
                                ctx.drawTag(tag, color: color,
                                            topLeft: CGPoint(x: rect.minX + 1, y: rect.minY + 1),
                                            fontSize: 10)
                            }
                        }
                    } else {
                        ContentUnavailableView("No image", systemImage: "photo")
                    }
                }
                .contentShape(Rectangle())
                .overlay { ScrollCatcher { applyScroll($0) } }
                .gesture(panGesture)
                .simultaneousGesture(magnifyGesture)
                .overlay(alignment: .bottomTrailing) {
                    if cgImage != nil { ZoomControls(zoom: $zoom, pan: $pan) }
                }
                .onChange(of: geo.size) { containerSize = geo.size }
                .onAppear { containerSize = geo.size }
            }
        }
        .padding()
        .task(id: refreshKey) { await refresh() }
        .onChange(of: model.currentImageURL) { zoom = 1; pan = .zero }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .updating($gestureZoom) { value, state, _ in state = value }
            .onEnded { value in
                zoom = Zoom.clamp(zoom * value)
                if zoom == 1 { pan = .zero }
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($gesturePan) { value, state, _ in state = value.translation }
            .onEnded { value in
                let raw = CGSize(width: pan.width + value.translation.width,
                                 height: pan.height + value.translation.height)
                let base = EditorGeometry(container: containerSize, imagePixelSize: pixelSize).baseSize
                let display = CGSize(width: base.width * zoom, height: base.height * zoom)
                pan = EditorGeometry.clampPan(raw, container: containerSize, display: display)
            }
    }

    private func applyScroll(_ delta: CGSize) {
        guard zoom > 1 else { return }
        let base = EditorGeometry(container: containerSize, imagePixelSize: pixelSize).baseSize
        let display = CGSize(width: base.width * zoom, height: base.height * zoom)
        let raw = CGSize(width: pan.width + delta.width, height: pan.height + delta.height)
        pan = EditorGeometry.clampPan(raw, container: containerSize, display: display)
    }

    private var refreshKey: String {
        "\(model.currentImageURL?.path ?? "")|\(source.rawValue)"
    }

    private var boxesToShow: [Box] {
        source == .labels ? model.currentBoxes : predictions
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Overlay", selection: $source) {
                ForEach(Source.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack {
                Button("Export preview JPEG") { exportPreview() }
                    .disabled(cgImage == nil)
                Spacer()
                modelBadge
            }
            if !note.isEmpty {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var modelBadge: some View {
        if let p = model.paths {
            let avail = ModelAvailability.check(in: p.outputDir)
            HStack(spacing: 8) {
                badge("detector", avail.detector)
                badge("rank", avail.rank)
                badge("clear", avail.clearType)
            }
            .help(avail.anyMissing
                  ? "Live CoreML inference needs exported .mlpackage models (run export_coreml.py)."
                  : "All exported models present.")
        }
    }

    private func badge(_ name: String, _ present: Bool) -> some View {
        Label(name, systemImage: present ? "checkmark.circle.fill" : "xmark.circle")
            .font(.caption)
            .foregroundStyle(present ? .green : .secondary)
    }

    private func refresh() async {
        note = ""
        guard let url = model.currentImageURL else { cgImage = nil; return }
        let loaded = await Task.detached { () -> (CGImage?, CGSize) in
            let img = ImageDecoder.load(url)
            return (img, img.map { CGSize(width: $0.width, height: $0.height) } ?? .zero)
        }.value
        cgImage = loaded.0
        pixelSize = loaded.1

        if source == .predictions {
            if let p = model.paths, let set = LabelStore.loadFile(p.predictionsFile),
               let boxes = set.byImage[url.lastPathComponent] {
                predictions = boxes
            } else {
                predictions = []
                note = "No predictions.json entry for this image (run Training/scripts/predict.py)."
            }
        } else if source == .coreml {
            await runCoreML(on: url)
        }
    }

    private func runCoreML(on url: URL) async {
        guard let p = model.paths else { predictions = []; return }
        let modelURL = p.modelURL(named: model.config.productionModelName)
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            predictions = []
            note = "\(model.workspace.title) model not found — run Export CoreML."
            return
        }
        note = "Running CoreML…"
        let schema = model.schema
        let postProcess = model.config.usesPostProcess
        do {
            let boxes = try await Task.detached { () throws -> [Box] in
                guard let cg = ImageDecoder.load(url) else { return [] }
                return try CoreMLPipeline.detect(
                    cg, modelURL: modelURL, schema: schema, postProcess: postProcess)
            }.value
            predictions = boxes
            note = "CoreML: \(boxes.count) detections"
        } catch {
            predictions = []
            note = "CoreML error: \(error.localizedDescription)"
        }
    }

    private func exportPreview() {
        guard let cgImage, let p = model.paths, let name = model.currentImageName else { return }
        let stem = (name as NSString).deletingPathExtension
        let out = p.previewDir.appending(path: "\(stem).jpg")
        if PreviewExport.render(image: cgImage, boxes: boxesToShow, to: out) {
            note = "Wrote \(out.path)"
        } else {
            note = "Export failed."
        }
    }
}
