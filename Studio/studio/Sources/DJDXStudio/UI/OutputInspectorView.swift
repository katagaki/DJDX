import SwiftUI

struct OutputInspectorView: View {
    @Environment(AppModel.self) private var model

    @State private var cgImage: CGImage?
    @State private var pixelSize: CGSize = .zero
    @State private var predictions: [Box] = []
    @State private var source: Source = .labels
    @State private var note: String = ""

    enum Source: String, CaseIterable, Identifiable {
        case labels = "labels.json"
        case predictions = "predictions.json"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 8) {
            header
            GeometryReader { geo in
                let geom = EditorGeometry(container: geo.size, imagePixelSize: pixelSize)
                ZStack {
                    Color(nsColor: .underPageBackgroundColor)
                    if let cgImage {
                        Image(decorative: cgImage, scale: 1, orientation: .up)
                            .resizable()
                            .frame(width: geom.displaySize.width, height: geom.displaySize.height)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        Canvas { ctx, _ in
                            for box in boxesToShow {
                                let rect = geom.rect(for: box)
                                let color = ClassColor.color(for: box.cls)
                                ctx.stroke(Path(rect), with: .color(color), lineWidth: 2)
                                var tag = box.cls
                                if let c = box.conf { tag += String(format: " %.2f", c) }
                                ctx.draw(Text(tag).font(.system(size: 10)).foregroundStyle(color),
                                         at: CGPoint(x: rect.minX + 3, y: rect.minY + 8), anchor: .leading)
                            }
                        }
                    } else {
                        ContentUnavailableView("No image", systemImage: "photo")
                    }
                }
            }
        }
        .padding()
        .task(id: refreshKey) { await refresh() }
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
                note = "No predictions.json entry for this image (run scripts/predict.py)."
            }
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
