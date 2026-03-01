//
//  DJLevelWidgetView.swift
//  Widgets
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import Charts
import SwiftUI
import WidgetKit

struct DJLevelWidget: Widget {
    let kind: String = "DJLevelWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: DJLevelWidgetIntent.self,
                               provider: DJLevelProvider()) { entry in
            DJLevelWidgetView(entry: entry)
                .widgetAccentable(false)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Widget.DJLevel.Name")
        .description("Widget.DJLevel.Description")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct DJLevelWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: DJLevelEntry

    var body: some View {
        switch entry.configuration.chartDisplay {
        case .trend:
            if let trendData = entry.trendData, !trendData.isEmpty {
                WidgetDJLevelTrendChart(trendData: trendData)
            } else {
                noDataView
            }
        case .pie:
            if let data = entry.dataPerDifficulty, !data.isEmpty {
                WidgetDJLevelPieChart(data: aggregateAllDifficulties(data))
            } else {
                noDataView
            }
        case .bar:
            if let data = entry.dataPerDifficulty, !data.isEmpty {
                WidgetDJLevelBarChart(data: aggregateAllDifficulties(data))
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
            Text("Widget.DJLevel.NoData")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func aggregateAllDifficulties(_ data: [Int: [String: Int]]) -> [String: Int] {
        var result: [String: Int] = [:]
        for (_, djLevels) in data {
            for (djLevel, count) in djLevels {
                result[djLevel, default: 0] += count
            }
        }
        return result
    }
}
