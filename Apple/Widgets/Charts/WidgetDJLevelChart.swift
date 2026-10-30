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
    let level: Int

    private static let djLevelOrder = ["F", "E", "D", "C", "B", "A", "AA", "AAA"]

    var body: some View {
        let sortedKeys = trendData.keys.sorted()
        if !sortedKeys.isEmpty {
            Chart(sortedKeys, id: \.self) { dateKey in
                let dataForLevel = trendData[dateKey]?[level] ?? [:]
                let date = Date(timeIntervalSince1970: Double(dateKey) ?? 0)
                ForEach(Self.djLevelOrder.reversed(), id: \.self) { djLevel in
                    let count = dataForLevel[djLevel] ?? 0
                    AreaMark(
                        x: .value("Date", date),
                        y: .value("Count", count)
                    )
                    .foregroundStyle(by: .value("DJ Level", djLevel))
                }
            }
            .chartForegroundStyleScale(WidgetDJLevelColors.scale)
            .chartLegend(.hidden)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        }
    }
}

enum WidgetDJLevelColors {
    static let scale: KeyValuePairs<String, Color> = [
        "AAA": Color(red: 1.0, green: 0.8, blue: 0.16),
        "AA": Color(red: 0.62, green: 0.65, blue: 0.68),
        "A": Color(red: 0.4, green: 0.9, blue: 0.8),
        "B": Color(red: 0.32, green: 0.84, blue: 0.92),
        "C": Color(red: 0.24, green: 0.7, blue: 0.96),
        "D": Color(red: 0.24, green: 0.56, blue: 0.98),
        "E": Color(red: 0.2, green: 0.44, blue: 0.96),
        "F": Color(red: 0.16, green: 0.34, blue: 0.92)
    ]
}
