//
//  WidgetClearTypeChart.swift
//  Widgets
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import Charts
import SwiftUI

struct WidgetClearTypePieChart: View {
    let data: [String: Int]

    private static let clearTypeOrder = [
        "FULLCOMBO CLEAR", "CLEAR", "EASY CLEAR", "ASSIST CLEAR",
        "HARD CLEAR", "EX HARD CLEAR", "FAILED"
    ]

    var body: some View {
        let filteredData = Self.clearTypeOrder.filter { (data[$0] ?? 0) > 0 }
        if !filteredData.isEmpty {
            Chart(filteredData, id: \.self) { clearType in
                SectorMark(angle: .value(clearType, data[clearType] ?? 0))
                    .foregroundStyle(by: .value("Clear Type", clearType))
            }
            .chartForegroundStyleScale(WidgetClearTypeColors.scale)
            .chartLegend(.hidden)
        }
    }
}

struct WidgetClearTypeBarChart: View {
    let data: [String: Int]

    private static let clearTypeOrder = [
        "FULLCOMBO CLEAR", "CLEAR", "EASY CLEAR", "ASSIST CLEAR",
        "HARD CLEAR", "EX HARD CLEAR", "FAILED"
    ]

    var body: some View {
        let filteredData = Self.clearTypeOrder.filter { (data[$0] ?? 0) > 0 }
        if !filteredData.isEmpty {
            Chart(filteredData, id: \.self) { clearType in
                BarMark(
                    x: .value("Clear Type", String(clearType.prefix(2))),
                    y: .value("Count", data[clearType] ?? 0),
                    width: .automatic
                )
                .foregroundStyle(by: .value("Clear Type", clearType))
            }
            .chartForegroundStyleScale(WidgetClearTypeColors.scale)
            .chartLegend(.hidden)
            .chartXAxis(.hidden)
        }
    }
}

struct WidgetClearTypeTrendChart: View {
    let trendData: [String: [Int: [String: Int]]]
    let level: Int

    private static let clearTypeOrder = [
        "FULLCOMBO CLEAR", "CLEAR", "EASY CLEAR", "ASSIST CLEAR",
        "HARD CLEAR", "EX HARD CLEAR", "FAILED"
    ]

    var body: some View {
        let sortedKeys = trendData.keys.sorted()
        if !sortedKeys.isEmpty {
            Chart(sortedKeys, id: \.self) { dateKey in
                let dataForLevel = trendData[dateKey]?[level] ?? [:]
                let date = Date(timeIntervalSince1970: Double(dateKey) ?? 0)
                ForEach(Self.clearTypeOrder.reversed(), id: \.self) { clearType in
                    let count = dataForLevel[clearType] ?? 0
                    AreaMark(
                        x: .value("Date", date),
                        y: .value("Count", count)
                    )
                    .foregroundStyle(by: .value("Clear Type", clearType))
                    .interpolationMethod(.monotone)
                }
            }
            .chartForegroundStyleScale(WidgetClearTypeColors.scale)
            .chartLegend(.hidden)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        }
    }
}

enum WidgetClearTypeColors {
    static let scale: KeyValuePairs<String, Color> = [
        "FULLCOMBO CLEAR": .blue,
        "CLEAR": .cyan,
        "EASY CLEAR": .green,
        "ASSIST CLEAR": .purple,
        "HARD CLEAR": .pink,
        "EX HARD CLEAR": .yellow,
        "FAILED": .red
    ]
}
