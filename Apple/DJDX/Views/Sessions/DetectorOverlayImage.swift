import SwiftUI

enum DetectorOverlayMode: CaseIterable {
    case plain, boxes, digits, ranks

    var next: DetectorOverlayMode {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    var badge: String? {
        switch self {
        case .plain: nil
        case .boxes: "BOXES"
        case .digits: "DIGITS"
        case .ranks: "RANKS"
        }
    }
}

struct DetectorOverlayImage: View {
    let image: UIImage
    let imageFilename: String

    @State private var mode: DetectorOverlayMode = .plain
    @State private var regions: [DetectedRegion] = []
    @State private var didDetect = false
    @State private var isDetecting = false

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { proxy in
                    overlayContent(in: renderedRect(in: proxy.size))
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) { badge }
            .contentShape(Rectangle())
            .onTapGesture { advance() }
    }

    @ViewBuilder
    private var badge: some View {
        if let text = mode.badge {
            Text(verbatim: text)
                .font(.system(size: 11.0, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8.0)
                .padding(.vertical, 4.0)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(8.0)
        }
    }

    private func overlayContent(in rect: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(visibleRegions.enumerated()), id: \.offset) { _, region in
                let frame = boxFrame(region.box, in: rect)
                Rectangle()
                    .strokeBorder(color(for: region.label), lineWidth: 1.5)
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
                if let flag = flagText(for: region) {
                    flagView(flag, color: color(for: region.label))
                        .offset(x: frame.minX, y: max(0.0, frame.minY - 15.0))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func flagView(_ text: String, color: Color) -> some View {
        Text(verbatim: text)
            .font(.system(size: 10.0, weight: .bold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 3.0)
            .padding(.vertical, 1.0)
            .background(color, in: RoundedRectangle(cornerRadius: 3.0))
            .fixedSize()
    }

    private var visibleRegions: [DetectedRegion] {
        switch mode {
        case .plain: []
        case .boxes: regions
        case .digits: regions.filter { IIDXResultReader.digitLabels.contains($0.label) }
        case .ranks: regions.filter { $0.label == "dj_level_now" }
        }
    }

    private func flagText(for region: DetectedRegion) -> String? {
        switch mode {
        case .digits, .ranks:
            let text = region.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        case .plain, .boxes:
            return nil
        }
    }

    private func color(for label: String) -> Color {
        if label == "dj_level_now" || label == "dj_level_prev" { return .purple }
        if IIDXResultReader.digitLabels.contains(label) { return .teal }
        if label == "song_title" || label == "song_artist" { return .yellow }
        return .green
    }

    private func renderedRect(in container: CGSize) -> CGRect {
        guard image.size.width > 0.0, image.size.height > 0.0 else { return .zero }
        let scale = min(container.width / image.size.width, container.height / image.size.height)
        let width = image.size.width * scale
        let height = image.size.height * scale
        return CGRect(
            x: (container.width - width) / 2.0,
            y: (container.height - height) / 2.0,
            width: width,
            height: height
        )
    }

    private func boxFrame(_ box: CGRect, in rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX + box.minX * rect.width,
            y: rect.minY + (1.0 - box.maxY) * rect.height,
            width: box.width * rect.width,
            height: box.height * rect.height
        )
    }

    private func advance() {
        let next = mode.next
        if next != .plain { detectIfNeeded() }
        withAnimation(.smooth) { mode = next }
    }

    private func detectIfNeeded() {
        guard !didDetect, !isDetecting else { return }
        isDetecting = true
        let filename = imageFilename
        Task {
            let detected = await Task.detached { () -> [DetectedRegion] in
                guard let data = IIDXSessionImageStore.shared.data(for: filename) else { return [] }
                return (try? await IIDXResultReader.detect(imageData: data)) ?? []
            }.value
            withAnimation(.smooth) { regions = detected }
            didDetect = true
            isDetecting = false
        }
    }
}
