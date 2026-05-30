//
//  AnalyticsChartLegend.swift
//  DJDX
//
//  Created by Claude on 2026/05/30.
//

import SwiftUI

// A compact two-column wrapping legend used in place of the built-in chart
// legend, which overflows horizontally when there are many categories.
struct AnalyticsChartLegend: View {

    let items: [(label: String, color: Color)]

    let columns = [
        GridItem(.flexible(), alignment: .leading),
        GridItem(.flexible(), alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 4.0) {
            ForEach(items, id: \.label) { item in
                HStack(spacing: 6.0) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 8.0, height: 8.0)
                    Text(verbatim: item.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0.0)
                }
            }
        }
        .padding(.vertical, 2.0)
    }
}

struct ClearTypeLegend: View {
    var body: some View {
        AnalyticsChartLegend(
            items: IIDXClearType.sortedWithoutNoPlay.map {
                ($0.rawValue, IIDXClearType.color(for: $0.rawValue))
            }
        )
    }
}

struct DJLevelLegend: View {
    var body: some View {
        AnalyticsChartLegend(
            items: IIDXDJLevel.sorted.reversed().map {
                ($0.rawValue, IIDXDJLevel.color(for: $0.rawValue))
            }
        )
    }
}
