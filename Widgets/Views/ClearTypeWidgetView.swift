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
        .configurationDisplayName("Shared.IIDX.ClearType")
        .description("Widget.ClearType.Description")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ClearTypeWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: ClearTypeEntry

    var selectedLevel: Int {
        entry.configuration.level.rawValue
    }

    var body: some View {
        switch entry.configuration.chartDisplay {
        case .trend:
            if let trendData = entry.trendData, !trendData.isEmpty {
                WidgetClearTypeTrendChart(trendData: trendData, level: selectedLevel)
            } else {
                noDataView
            }
        case .pie:
            if let data = entry.dataPerDifficulty,
               let levelData = dataForSelectedLevel(data) {
                WidgetClearTypePieChart(data: levelData)
            } else {
                noDataView
            }
        case .bar:
            if let data = entry.dataPerDifficulty,
               let levelData = dataForSelectedLevel(data) {
                WidgetClearTypeBarChart(data: levelData)
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
            Text("Shared.IIDX.NoData")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func dataForSelectedLevel(_ data: [Int: [String: Int]]) -> [String: Int]? {
        guard let levelData = data[selectedLevel], !levelData.isEmpty else {
            return nil
        }
        return levelData
    }
}
