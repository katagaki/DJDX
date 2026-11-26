import SwiftUI

struct DifficultySegmentedPicker<Tag: Hashable>: View {

    struct Segment: Identifiable {
        var tag: Tag
        var number: String
        var name: Text
        var color: Color
        var id: Tag { tag }
    }

    var segments: [Segment]
    @Binding var selection: Tag

    @State private var segmentFrames: [Int: CGRect] = [:]
    @State private var isScrubbing: Bool = false

    private let coordinateSpaceName = "DifficultySegmentedPicker"

    private var selectedIndex: Int? {
        segments.firstIndex { $0.tag == selection }
    }

    private var selectionColor: Color {
        segments.first { $0.tag == selection }?.color ?? .accentColor
    }

    var body: some View {
        let content = HStack(spacing: 4.0) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                segmentButton(segment)
                    .layoutPriority(selection == segment.tag ? 1.0 : 0.0)
                    .background { frameReader(index: index) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(4.0)
        .background { selectionHighlight }
        .coordinateSpace(.named(coordinateSpaceName))
        .onPreferenceChange(SegmentFramePreferenceKey.self) { segmentFrames = $0 }
        .simultaneousGesture(dragGesture)
        .sensoryFeedback(.selection, trigger: selection)

        content
            .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 20.0))
    }

    @ViewBuilder
    private var selectionHighlight: some View {
        if let index = selectedIndex, let frame = segmentFrames[index] {
            RoundedRectangle(cornerRadius: 16.0)
                .fill(LinearGradient(colors: [selectionColor.mix(with: .white, by: 0.35), selectionColor],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
        }
    }

    @ViewBuilder
    private func segmentButton(_ segment: Segment) -> some View {
        let isSelected = selection == segment.tag
        Button {
            withAnimation(.smooth.speed(2.0)) {
                selection = segment.tag
            }
        } label: {
            HStack(spacing: 7.0) {
                if isSelected {
                    segment.name
                        .font(.system(size: 11.0, weight: .black))
                        .fontWidth(.condensed)
                        .kerning(0.4)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .transition(.opacity)
                }
                LevelNumber(level: segment.number, size: 22.0, tint: segment.color, isColored: !isSelected)
                    .shadow(color: .black.opacity(isSelected ? 0.35 : 0.0), radius: 0.0, y: 1.0)
            }
            .padding(.horizontal, isSelected ? 12.0 : 0.0)
            .frame(maxWidth: isSelected ? nil : .infinity)
            .frame(height: 40.0)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func frameReader(index: Int) -> some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: SegmentFramePreferenceKey.self,
                            value: [index: proxy.frame(in: .named(coordinateSpaceName))])
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0.0, coordinateSpace: .named(coordinateSpaceName))
            .onChanged { value in
                if !isScrubbing {
                    guard let index = selectedIndex,
                          let frame = segmentFrames[index],
                          frame.contains(value.startLocation) else { return }
                    isScrubbing = true
                }
                select(at: value.location.x)
            }
            .onEnded { _ in
                isScrubbing = false
            }
    }

    private func select(at positionX: CGFloat) {
        guard let index = segmentIndex(at: positionX), segments.indices.contains(index) else { return }
        let tag = segments[index].tag
        if tag != selection {
            withAnimation(.smooth.speed(2.0)) {
                selection = tag
            }
        }
    }

    private func segmentIndex(at positionX: CGFloat) -> Int? {
        if let exact = segmentFrames.first(where: {
            $0.value.minX <= positionX && positionX <= $0.value.maxX
        })?.key {
            return exact
        }
        return segmentFrames.min(by: {
            abs($0.value.midX - positionX) < abs($1.value.midX - positionX)
        })?.key
    }
}

private struct SegmentFramePreferenceKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
