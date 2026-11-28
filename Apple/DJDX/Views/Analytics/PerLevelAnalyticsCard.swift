import SwiftUI

struct PerLevelSegment: Identifiable {
    var id: String { label }
    let label: String
    let color: Color
    let count: Int
    let metallicLabel: IIDXMetallicText
    var isFullCombo: Bool = false
}

struct PerLevelAnalyticsCard<TrendChart: View>: View {

    let difficulty: Int
    let subtitle: LocalizedStringKey
    let showsBar: Bool
    let segments: [PerLevelSegment]
    @ViewBuilder let trendChart: () -> TrendChart

    var total: Int {
        segments.reduce(0) { $0 + $1.count }
    }

    var visibleSegments: [PerLevelSegment] {
        Array(segments.filter { $0.count > 0 }.prefix(4))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if !showsBar {
                trendChart()
                    .padding(.leading, 120.0)
                    .allowsHitTesting(false)
            }
            VStack(alignment: .leading, spacing: 4.0) {
                HStack(alignment: .center, spacing: 6.0) {
                    LevelNumberBadge(level: String(difficulty))
                    Text(subtitle)
                        .cardLabel()
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                    if showsBar {
                        segmentedBar
                    }
                }
                if showsBar {
                    statsRow
                }
            }
            .padding(DesignMetrics.cardPadding)
        }
        .frame(height: DesignMetrics.perLevelHeight, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    var segmentedBar: some View {
        GeometryReader { geometry in
            let shownSegments = segments.filter { $0.count > 0 }
            let gaps = DesignMetrics.barSegmentGap * CGFloat(max(shownSegments.count - 1, 0))
            HStack(spacing: DesignMetrics.barSegmentGap) {
                ForEach(shownSegments) { segment in
                    Group {
                        if segment.isFullCombo {
                            FullComboRainbowFill()
                        } else {
                            segment.color
                        }
                    }
                    .frame(width: (geometry.size.width - gaps) * CGFloat(segment.count) / CGFloat(max(total, 1)))
                }
            }
        }
        .frame(height: DesignMetrics.barHeight)
    }

    var statsRow: some View {
        ViewThatFits(in: .horizontal) {
            statsRowContent(isFixed: true)
            statsRowContent(isFixed: false)
        }
    }

    func statsRowContent(isFixed: Bool) -> some View {
        HStack(spacing: 6.0) {
            ForEach(visibleSegments) { segment in
                HStack(spacing: 2.0) {
                    segment.metallicLabel
                        .fixedSize(horizontal: isFixed, vertical: false)
                    Text(verbatim: "\(segment.count)")
                        .font(.scoreline(size: 10.0, weight: .bold, width: .condensed))
                        .fixedSize()
                        .foregroundStyle(.primary)
                }
                .font(.caption2)
            }
            Spacer(minLength: 0.0)
        }
    }
}
