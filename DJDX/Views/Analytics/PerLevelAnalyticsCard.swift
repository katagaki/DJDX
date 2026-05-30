//
//  PerLevelAnalyticsCard.swift
//  DJDX
//
//  Created by Claude on 2026/05/30.
//

import SwiftUI

struct PerLevelSegment: Identifiable {
    var id: String { label }
    let label: String
    let color: Color
    let count: Int
}

// A full-width per-level card: title and subtitle over a faint trend chart,
// with an optional segmented makeup bar and a top-counts row for static cards.
struct PerLevelAnalyticsCard<TrendChart: View>: View {

    @Environment(\.colorScheme) var colorScheme

    let difficulty: Int
    let subtitle: LocalizedStringKey
    let showsBar: Bool
    let segments: [PerLevelSegment]
    @ViewBuilder let trendChart: () -> TrendChart

    var cornerRadius: CGFloat {
        if #available(iOS 26.0, *) { 20.0 } else { 12.0 }
    }

    var total: Int {
        segments.reduce(0) { $0 + $1.count }
    }

    // The three largest segments, ordered by count descending.
    var topSegments: [PerLevelSegment] {
        Array(
            segments.filter { $0.count > 0 }
                .sorted { $0.count > $1.count }
                .prefix(3)
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            trendChart()
                .padding(.top, cornerRadius)
                .opacity(showsBar ? 0.2 : 1.0)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0.0) {
                HStack(alignment: .center, spacing: 6.0) {
                    Group {
                        Text(verbatim: "LEVEL \(difficulty)")
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
        .background {
            switch colorScheme {
            case .light: Color.white
            case .dark: Color.clear.background(.regularMaterial)
            @unknown default: Color.clear
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius))
    }

    var segmentedBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 0.0) {
                ForEach(segments.filter { $0.count > 0 }) { segment in
                    segment.color
                        .frame(width: geometry.size.width * CGFloat(segment.count) / CGFloat(max(total, 1)))
                }
            }
            .clipShape(.rect(cornerRadius: 3.0))
        }
        .frame(height: 10.0)
    }

    var statsRow: some View {
        HStack(spacing: 10.0) {
            ForEach(topSegments) { segment in
                HStack(spacing: 3.0) {
                    Text(verbatim: segment.label)
                        .foregroundStyle(segment.color)
                        .fontWeight(.heavy)
                    Text(verbatim: "\(segment.count)")
                        .foregroundStyle(.primary)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .font(.caption2)
            }
            Spacer(minLength: 0.0)
        }
    }
}
