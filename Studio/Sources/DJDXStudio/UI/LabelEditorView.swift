import SwiftUI

private let handleSize: CGFloat = 8
private let minDrag: CGFloat = 4

private enum DragMode: Equatable {
    case new
    case move
    case resize(String)   // "nw" | "ne" | "sw" | "se"
}

struct LabelEditorView: View {
    @Environment(AppModel.self) private var model

    var trailingInset: CGFloat = 0

    @State private var cgImage: CGImage?
    @State private var pixelSize: CGSize = .zero
    @State private var dragMode: DragMode?
    @State private var dragStart: CGPoint?
    @State private var dragOrigin: Box?
    @State private var previewRect: CGRect?
    @FocusState private var focused: Bool

    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var containerSize: CGSize = .zero
    @GestureState private var gestureZoom: CGFloat = 1
    @GestureState private var gesturePan: CGSize = .zero

    private var effectiveZoom: CGFloat { Zoom.clamp(zoom * gestureZoom) }
    private var effectivePan: CGSize {
        CGSize(width: pan.width + gesturePan.width, height: pan.height + gesturePan.height)
    }

    var body: some View {
        GeometryReader { geo in
            // Reserve space on the right so the image never sits under the
            // floating Classes panel; the dark background still fills edge to edge.
            let area = CGSize(width: max(0, geo.size.width - trailingInset), height: geo.size.height)
            let geom = EditorGeometry(container: area, imagePixelSize: pixelSize,
                                      zoom: effectiveZoom, pan: effectivePan)
            ZStack {
                Color(nsColor: .underPageBackgroundColor)
                if let cgImage {
                    Image(decorative: cgImage, scale: 1, orientation: .up)
                        .resizable()
                        .frame(width: geom.displaySize.width, height: geom.displaySize.height)
                        .position(x: geom.offset.x + geom.displaySize.width / 2,
                                  y: geom.offset.y + geom.displaySize.height / 2)
                    Canvas { ctx, _ in draw(in: ctx, geom: geom) }
                } else {
                    ContentUnavailableView("No image", systemImage: "photo")
                }
            }
            .contentShape(Rectangle())
            .overlay { ScrollCatcher { applyScroll($0) } }
            .highPriorityGesture(panGesture)
            .gesture(drag(geom: geom))
            .simultaneousGesture(magnifyGesture)
            .focusable()
            .focused($focused)
            .focusEffectDisabled()
            .onKeyPress { handleKey($0) }
            .overlay(alignment: .bottomTrailing) {
                ZoomControls(zoom: $zoom, pan: $pan).padding(.trailing, trailingInset)
            }
            .onChange(of: area) { containerSize = area }
            .onAppear { containerSize = area }
        }
        .task(id: model.currentImageURL) { await loadImage() }
        .onChange(of: model.currentImageURL) {
            previewRect = nil; dragMode = nil; zoom = 1; pan = .zero
        }
        .onAppear { focused = true }
    }

    // MARK: - Zoom / pan gestures

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .updating($gestureZoom) { value, state, _ in state = value }
            .onEnded { value in
                zoom = Zoom.clamp(zoom * value)
                if zoom == 1 { pan = .zero }
            }
    }

    // Hold ⌥ Option and drag to pan, leaving plain drag for box editing.
    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .modifiers(.option)
            .updating($gesturePan) { value, state, _ in state = value.translation }
            .onEnded { value in
                let raw = CGSize(width: pan.width + value.translation.width,
                                 height: pan.height + value.translation.height)
                let display = CGSize(width: pixelFit().width * zoom, height: pixelFit().height * zoom)
                pan = EditorGeometry.clampPan(raw, container: containerSize, display: display)
            }
    }

    private func pixelFit() -> CGSize {
        EditorGeometry(container: containerSize, imagePixelSize: pixelSize).baseSize
    }

    private func applyScroll(_ delta: CGSize) {
        guard zoom > 1 else { return }
        let base = pixelFit()
        let display = CGSize(width: base.width * zoom, height: base.height * zoom)
        let raw = CGSize(width: pan.width + delta.width, height: pan.height + delta.height)
        pan = EditorGeometry.clampPan(raw, container: containerSize, display: display)
    }

    // MARK: - Drawing

    private func draw(in ctx: GraphicsContext, geom: EditorGeometry) {
        for box in model.currentBoxes {
            let rect = geom.rect(for: box)
            let color = ClassColor.color(for: box.cls)
            let selected = box.id == model.selectedBoxID
            ctx.stroke(Path(rect), with: .color(color), lineWidth: selected ? 3 : 2)

            var tag = box.cls
            if let c = box.conf { tag += String(format: " %.2f", c) }
            ctx.drawTag(tag, color: color, topLeft: CGPoint(x: rect.minX + 1, y: rect.minY + 1),
                        bold: selected)

            if selected {
                for c in corners(rect) {
                    let h = CGRect(x: c.x - handleSize / 2, y: c.y - handleSize / 2,
                                   width: handleSize, height: handleSize)
                    ctx.fill(Path(h), with: .color(.white))
                    ctx.stroke(Path(h), with: .color(color), lineWidth: 1)
                }
            }
        }
        if let previewRect {
            ctx.stroke(Path(previewRect), with: .color(.white), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
    }

    private func corners(_ r: CGRect) -> [CGPoint] {
        [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
         CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY)]
    }

    // MARK: - Gesture

    private func drag(geom: EditorGeometry) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragMode == nil {
                    begin(at: value.startLocation, geom: geom)
                }
                update(to: value.location, geom: geom)
            }
            .onEnded { value in
                finish(at: value.location, geom: geom)
            }
    }

    private func begin(at p: CGPoint, geom: EditorGeometry) {
        dragStart = p
        let (idx, hit) = hitTest(p, geom: geom)
        if let idx {
            let box = model.currentBoxes[idx]
            model.selectedBoxID = box.id
            dragOrigin = box
            dragMode = (hit == "body" || hit == nil) ? .move : .resize(hit!)
        } else {
            model.selectedBoxID = nil
            dragMode = .new
        }
    }

    private func update(to p: CGPoint, geom: EditorGeometry) {
        guard let start = dragStart, let mode = dragMode else { return }
        switch mode {
        case .new:
            guard abs(p.x - start.x) >= minDrag || abs(p.y - start.y) >= minDrag else { return }
            previewRect = CGRect(x: min(start.x, p.x), y: min(start.y, p.y),
                                 width: abs(p.x - start.x), height: abs(p.y - start.y))
        case .move:
            guard var box = dragOrigin else { return }
            let dx = (p.x - start.x) / geom.displaySize.width
            let dy = (p.y - start.y) / geom.displaySize.height
            box.x = min(max(0, box.x + dx), 1 - box.w)
            box.y = min(max(0, box.y + dy), 1 - box.h)
            model.updateBox(box, pushUndo: false)
        case .resize(let corner):
            guard let orig = dragOrigin else { return }
            let n = geom.toNorm(p)
            var x1 = orig.x, y1 = orig.y, x2 = orig.x + orig.w, y2 = orig.y + orig.h
            if corner.contains("w") { x1 = n.x }
            if corner.contains("e") { x2 = n.x }
            if corner.contains("n") { y1 = n.y }
            if corner.contains("s") { y2 = n.y }
            var box = orig
            box.x = min(x1, x2); box.y = min(y1, y2)
            box.w = abs(x2 - x1); box.h = abs(y2 - y1)
            model.updateBox(box, pushUndo: false)
        }
    }

    private func finish(at p: CGPoint, geom: EditorGeometry) {
        defer { dragMode = nil; dragStart = nil; dragOrigin = nil; previewRect = nil }
        guard let start = dragStart, let mode = dragMode else { return }
        switch mode {
        case .new:
            guard abs(p.x - start.x) >= minDrag, abs(p.y - start.y) >= minDrag else { return }
            let a = geom.toNorm(CGPoint(x: min(start.x, p.x), y: min(start.y, p.y)))
            let b = geom.toNorm(CGPoint(x: max(start.x, p.x), y: max(start.y, p.y)))
            let cls = model.currentClass ?? Schema.unlabeledText
            model.addBox(Box(cls: cls, x: a.x, y: a.y, w: b.x - a.x, h: b.y - a.y))
        case .move, .resize:
            if let box = model.selectedBox {
                // commit one undo snapshot for the whole drag
                model.updateBox(box, pushUndo: true)
            }
        }
        model.setStatus("")
    }

    private func hitTest(_ p: CGPoint, geom: EditorGeometry) -> (Int?, String?) {
        let boxes = model.currentBoxes
        for i in boxes.indices.reversed() {
            let r = geom.rect(for: boxes[i])
            let named: [(String, CGPoint)] = [
                ("nw", CGPoint(x: r.minX, y: r.minY)), ("ne", CGPoint(x: r.maxX, y: r.minY)),
                ("sw", CGPoint(x: r.minX, y: r.maxY)), ("se", CGPoint(x: r.maxX, y: r.maxY)),
            ]
            for (name, c) in named where abs(p.x - c.x) <= handleSize && abs(p.y - c.y) <= handleSize {
                return (i, name)
            }
            if r.contains(p) { return (i, "body") }
        }
        return (nil, nil)
    }

    // MARK: - Keyboard

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .leftArrow: model.prev(); return .handled
        case .rightArrow: model.next(); return .handled
        case .delete, .deleteForward: model.deleteSelected(); return .handled
        default: break
        }
        let ch = press.characters
        if ch == "=" || ch == "+" { zoom = Zoom.clamp(zoom * Zoom.step); return .handled }
        if ch == "-" || ch == "_" {
            zoom = Zoom.clamp(zoom / Zoom.step); if zoom == 1 { pan = .zero }; return .handled
        }
        if ch == "/" { model.cycleSelectedClass(); return .handled }
        // Assign classes by running across the keyboard: number row → top 10
        // classes, then QWERTY row, then the home row.
        if ch.count == 1, let idx = Schema.classHotkeyOrder.firstIndex(of: Character(ch.lowercased())) {
            let classes = model.schema.labelClasses
            if idx < classes.count { model.assignClassToSelection(classes[idx]) }
            return .handled
        }
        return .ignored
    }

    // MARK: - Image loading

    private func loadImage() async {
        guard let url = model.currentImageURL else { cgImage = nil; return }
        let loaded = await Task.detached { () -> (CGImage?, CGSize) in
            let img = ImageDecoder.load(url)
            let size = img.map { CGSize(width: $0.width, height: $0.height) } ?? .zero
            return (img, size)
        }.value
        cgImage = loaded.0
        pixelSize = loaded.1
    }
}
