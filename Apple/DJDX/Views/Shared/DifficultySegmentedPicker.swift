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

    var body: some View {
        let content = SegmentLayout(selectedIndex: selectedIndex, spacing: 4.0) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                segmentButton(segment)
                    .background { frameReader(index: index) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(4.0)
        .coordinateSpace(.named(coordinateSpaceName))
        .onPreferenceChange(SegmentFramePreferenceKey.self) { segmentFrames = $0 }
        .simultaneousGesture(dragGesture)
        .sensoryFeedback(.selection, trigger: selection)

        content
            .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 20.0))
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
            .frame(maxWidth: .infinity)
            .frame(height: 40.0)
            .background {
                RoundedRectangle(cornerRadius: 16.0)
                    .fill(LinearGradient(colors: [segment.color.mix(with: .white, by: 0.35), segment.color],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .opacity(isSelected ? 1.0 : 0.0)
            }
            .clipShape(.rect(cornerRadius: 16.0))
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

private struct SegmentLayout: Layout {
    var selectedIndex: Int?
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let idealWidth = sizes.reduce(0.0) { $0 + $1.width } + spacing * CGFloat(max(subviews.count - 1, 0))
        return CGSize(width: proposal.width ?? idealWidth, height: sizes.map(\.height).max() ?? 0.0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let available = max(bounds.width - spacing * CGFloat(subviews.count - 1), 0.0)
        let share = available / CGFloat(subviews.count)
        var widths = Array(repeating: share, count: subviews.count)
        if let selectedIndex, subviews.indices.contains(selectedIndex), subviews.count > 1 {
            let ideal = subviews[selectedIndex].sizeThatFits(.unspecified).width
            let selectedWidth = min(max(share, ideal), available)
            let otherWidth = (available - selectedWidth) / CGFloat(subviews.count - 1)
            widths = widths.indices.map { $0 == selectedIndex ? selectedWidth : otherWidth }
        }
        var positionX = bounds.minX
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: positionX, y: bounds.midY), anchor: .leading,
                          proposal: ProposedViewSize(width: widths[index], height: bounds.height))
            positionX += widths[index] + spacing
        }
    }
}

private struct SegmentFramePreferenceKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
