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

    var topSegments: [PerLevelSegment] {
        segments.filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            trendChart()
                .opacity(showsBar ? 0.2 : 1.0)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0.0) {
                VStack(alignment: .leading, spacing: 2.0) {
                    Text(verbatim: "LEVEL \(difficulty)")
                        .font(.title2.bold())
                    Text(subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0.0)
                if showsBar {
                    segmentedBar
                        .padding(.top, 12.0)
                    statsRow
                        .padding(.top, 8.0)
                }
            }
            .padding(16.0)
        }
        .frame(height: showsBar ? 150.0 : 110.0)
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
            .clipShape(.rect(cornerRadius: 4.0))
        }
        .frame(height: 16.0)
    }

    var statsRow: some View {
        HStack(spacing: 12.0) {
            ForEach(topSegments) { segment in
                HStack(spacing: 4.0) {
                    Text(verbatim: segment.label)
                        .foregroundStyle(segment.color)
                        .fontWeight(.heavy)
                    Text(verbatim: "\(segment.count)")
                        .foregroundStyle(.primary)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .font(.subheadline)
            }
            Spacer(minLength: 0.0)
        }
    }
}
