//
//  WidgetDJLevelChart.swift
//  Widgets
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import Charts
import SwiftUI

struct WidgetDJLevelPieChart: View {
    let data: [String: Int]

    private static let djLevelOrder = ["F", "E", "D", "C", "B", "A", "AA", "AAA"]

    var body: some View {
        let filteredData = Self.djLevelOrder.filter { (data[$0] ?? 0) > 0 }
        if !filteredData.isEmpty {
            Chart(filteredData, id: \.self) { djLevel in
                SectorMark(angle: .value(djLevel, data[djLevel] ?? 0))
                    .foregroundStyle(by: .value("DJ Level", djLevel))
            }
            .chartForegroundStyleScale(WidgetDJLevelColors.scale)
            .chartLegend(.hidden)
        }
    }
}

struct WidgetDJLevelBarChart: View {
    let data: [String: Int]

    private static let visibleLevels = ["C", "B", "A", "AA", "AAA"]

    var body: some View {
        Chart(Self.visibleLevels, id: \.self) { djLevel in
            BarMark(
                x: .value("DJ Level", djLevel),
                y: .value("Count", data[djLevel] ?? 0),
                width: .automatic
            )
            .foregroundStyle(by: .value("DJ Level", djLevel))
        }
        .chartXScale(domain: Self.visibleLevels)
        .chartForegroundStyleScale(WidgetDJLevelColors.scale)
        .chartLegend(.hidden)
    }
}

struct WidgetDJLevelTrendChart: View {
    let trendData: [String: [Int: [String: Int]]]

    private static let djLevelOrder = ["F", "E", "D", "C", "B", "A", "AA", "AAA"]

    var body: some View {
        let sortedKeys = trendData.keys.sorted()
        if !sortedKeys.isEmpty {
            Chart(sortedKeys, id: \.self) { dateKey in
                let aggregated = aggregateAllDifficulties(trendData[dateKey] ?? [:])
                let date = Date(timeIntervalSince1970: Double(dateKey) ?? 0)
                ForEach(Self.djLevelOrder.reversed(), id: \.self) { djLevel in
                    let count = aggregated[djLevel] ?? 0
                    AreaMark(
                        x: .value("Date", date),
                        y: .value("Count", count)
                    )
                    .foregroundStyle(by: .value("DJ Level", djLevel))
                    .interpolationMethod(.monotone)
                }
            }
            .chartForegroundStyleScale(WidgetDJLevelColors.scale)
            .chartLegend(.hidden)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
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

enum WidgetDJLevelColors {
    static let scale: KeyValuePairs<String, Color> = [
        "AAA": .primary,
        "AA": .orange,
        "A": .yellow,
        "B": .green,
        "C": .teal,
        "D": .blue,
        "E": .indigo,
        "F": .red
    ]
}
