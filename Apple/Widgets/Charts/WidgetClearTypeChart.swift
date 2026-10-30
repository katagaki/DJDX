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
        "FULLCOMBO CLEAR": Color(red: 0.45, green: 0.85, blue: 1.0),
        "CLEAR": Color(red: 0.3, green: 0.85, blue: 0.98),
        "EASY CLEAR": Color(red: 0.7, green: 0.93, blue: 0.3),
        "ASSIST CLEAR": Color(red: 0.7, green: 0.5, blue: 1.0),
        "HARD CLEAR": Color(red: 1.0, green: 0.28, blue: 0.32),
        "EX HARD CLEAR": Color(red: 1.0, green: 0.82, blue: 0.22),
        "FAILED": Color(red: 0.98, green: 0.4, blue: 0.27)
    ]
}
