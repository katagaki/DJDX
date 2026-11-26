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

    var cornerRadius: CGFloat {
        20.0
    }

    var total: Int {
        segments.reduce(0) { $0 + $1.count }
    }

    var visibleSegments: [PerLevelSegment] {
        Array(segments.filter { $0.count > 0 }.prefix(4))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            trendChart()
                .padding(.top, cornerRadius)
                .opacity(showsBar ? 0.2 : 1.0)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0.0) {
                HStack(alignment: .center, spacing: 6.0) {
                    LevelNumberBadge(level: String(difficulty))
                    Group {
                        Divider()
                            .frame(maxHeight: 14.0)
                        Text(subtitle)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption2.weight(.semibold))
                }
                Spacer(minLength: 0.0)
                if showsBar {
                    segmentedBar
                        .padding(.top, 8.0)
                    statsRow
                        .padding(.top, 6.0)
                }
            }
            .padding(12.0)
        }
        .frame(height: 72.0)
        .cardBackground(cornerRadius: cornerRadius)
    }

    var segmentedBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 0.0) {
                ForEach(segments.filter { $0.count > 0 }) { segment in
                    Group {
                        if segment.isFullCombo {
                            FullComboRainbowFill()
                        } else {
                            segment.color
                        }
                    }
                    .frame(width: geometry.size.width * CGFloat(segment.count) / CGFloat(max(total, 1)))
                }
            }
            .clipShape(.rect(cornerRadius: 3.0))
        }
        .frame(height: 10.0)
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
