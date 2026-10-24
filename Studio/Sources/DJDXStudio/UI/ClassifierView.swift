import SwiftUI

// Whole-image classification editor (DJ Level): show one crop big, pick a single
// class. Keyboard-first — number/letter hotkeys tag and advance; arrows navigate.
struct ClassifierView: View {
    @Environment(AppModel.self) private var model

    @State private var cgImage: CGImage?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 12) {
            tagBar
            imageArea
            classButtons
        }
        .padding(12)
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress { handleKey($0) }
        .task(id: model.currentImageURL) { await loadImage() }
        .onAppear { focused = true }
    }

    private var tagBar: some View {
        HStack(spacing: 8) {
            Text(model.currentImageName ?? "—")
                .font(.headline).lineLimit(1).truncationMode(.middle)
            Spacer()
            if let tag = model.currentTag {
                Text(tag)
                    .font(.headline.monospaced().bold())
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(ClassColor.color(for: tag), in: Capsule())
                    .foregroundStyle(.black)
            } else {
                Text("untagged").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var imageArea: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)
            if let cgImage {
                Image(decorative: cgImage, scale: 1, orientation: .up)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(8)
            } else {
                ContentUnavailableView("No image", systemImage: "photo")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var classButtons: some View {
        let hotkeys = model.hotkeys
        return HStack(spacing: 6) {
            ForEach(model.labelClasses, id: \.self) { cls in
                Button { model.tagCurrent(cls) } label: {
                    VStack(spacing: 2) {
                        Text(cls).font(.title3.monospaced().bold())
                        if let key = hotkeys.keyForClass[cls] {
                            Text(key.uppercased())
                                .font(.caption2.monospaced())
                                .foregroundStyle(.black.opacity(0.6))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(ClassColor.color(for: cls).opacity(0.85))
                    .foregroundStyle(.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.black, lineWidth: model.currentTag == cls ? 3 : 0))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .leftArrow: model.prev(); return .handled
        case .rightArrow: model.next(); return .handled
        case .delete, .deleteForward: model.clearCurrentLabels(); return .handled
        default: break
        }
        if let cls = model.hotkeys.classForKey[press.characters.lowercased()] {
            model.tagCurrent(cls)
            return .handled
        }
        return .ignored
    }

    private func loadImage() async {
        guard let url = model.currentImageURL else { cgImage = nil; return }
        cgImage = await Task.detached { ImageDecoder.load(url) }.value
    }
}
