//
//  ClearTypeWidgetView.swift
//  Widgets
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import Charts
import SwiftUI
import WidgetKit

struct ClearTypeWidget: Widget {
    let kind: String = "ClearTypeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ClearTypeWidgetIntent.self,
                               provider: ClearTypeProvider()) { entry in
            ClearTypeWidgetView(entry: entry)
                .widgetAccentable(false)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Widget.ClearType.Name")
        .description("Widget.ClearType.Description")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ClearTypeWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: ClearTypeEntry

    var body: some View {
        switch entry.configuration.chartDisplay {
        case .trend:
            if let trendData = entry.trendData, !trendData.isEmpty {
                WidgetClearTypeTrendChart(trendData: trendData)
            } else {
                noDataView
            }
        case .pie:
            if let data = entry.dataPerDifficulty, !data.isEmpty {
                WidgetClearTypePieChart(data: aggregateAllDifficulties(data))
            } else {
                noDataView
            }
        case .bar:
            if let data = entry.dataPerDifficulty, !data.isEmpty {
                WidgetClearTypeBarChart(data: aggregateAllDifficulties(data))
            } else {
                noDataView
            }
        }
    }

    private var noDataView: some View {
        VStack(spacing: 8.0) {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Widget.ClearType.NoData")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func aggregateAllDifficulties(_ data: [Int: [String: Int]]) -> [String: Int] {
        var result: [String: Int] = [:]
        for (_, clearTypes) in data {
            for (clearType, count) in clearTypes {
                result[clearType, default: 0] += count
            }
        }
        return result
    }
}
