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

    @State private var cgImage: CGImage?
    @State private var pixelSize: CGSize = .zero
    @State private var dragMode: DragMode?
    @State private var dragStart: CGPoint?
    @State private var dragOrigin: Box?
    @State private var previewRect: CGRect?
    @FocusState private var focused: Bool

    var body: some View {
        GeometryReader { geo in
            let geom = EditorGeometry(container: geo.size, imagePixelSize: pixelSize)
            ZStack {
                Color(nsColor: .underPageBackgroundColor)
                if let cgImage {
                    Image(decorative: cgImage, scale: 1, orientation: .up)
                        .resizable()
                        .frame(width: geom.displaySize.width, height: geom.displaySize.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    Canvas { ctx, _ in draw(in: ctx, geom: geom) }
                } else {
                    ContentUnavailableView("No image", systemImage: "photo")
                }
            }
            .contentShape(Rectangle())
            .gesture(drag(geom: geom))
            .focusable()
            .focused($focused)
            .focusEffectDisabled()
            .onKeyPress { handleKey($0) }
        }
        .task(id: model.currentImageURL) { await loadImage() }
        .onChange(of: model.currentImageURL) { previewRect = nil; dragMode = nil }
        .onAppear { focused = true }
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
            let text = Text(tag).font(.system(size: 11, weight: selected ? .bold : .regular)).foregroundStyle(color)
            ctx.draw(text, at: CGPoint(x: rect.minX + 4, y: rect.minY + 9), anchor: .leading)

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
        if ch == "/" { model.cycleSelectedClass(); return .handled }
        if let digit = Int(ch), (0...9).contains(digit) {
            let idx = (digit + 9) % 10   // 1..9 -> 0..8, 0 -> 9
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
