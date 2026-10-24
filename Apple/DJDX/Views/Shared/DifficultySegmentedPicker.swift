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

        if #available(iOS 26.0, *) {
            content
                .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 20.0))
        } else {
            content
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 20.0))
                .overlay {
                    RoundedRectangle(cornerRadius: 20.0)
                        .stroke(.secondary.opacity(0.2), lineWidth: 1.0)
                }
        }
    }

    @ViewBuilder
    private var selectionHighlight: some View {
        if let index = selectedIndex, let frame = segmentFrames[index] {
            RoundedRectangle(cornerRadius: 16.0)
                .fill(selectionColor)
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
            VStack(spacing: 1.0) {
                Text(verbatim: segment.number)
                    .font(.title3)
                    .fontWeight(.heavy)
                    .fontWidth(.expanded)
                segment.name
                    .font(.caption2)
                    .fontWeight(.bold)
                    .fontWidth(.condensed)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8.0)
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(segment.color))
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
