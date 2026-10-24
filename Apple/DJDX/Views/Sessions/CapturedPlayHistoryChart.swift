import Charts
import SwiftUI

struct CapturedPlayHistoryChart: View {
    var plays: [IIDXCapturedPlay]
    var noteCount: Int?

    private var series: [IIDXCapturedPlay] {
        plays.sorted { $0.captureDate < $1.captureDate }
    }

    private var dateRange: ClosedRange<Date> {
        let dates = series.map(\.captureDate)
        let earliest = dates.min() ?? .now
        let latest = dates.max() ?? .now
        let start = Calendar.current.date(byAdding: .hour, value: -1, to: earliest)!
        let end = Calendar.current.date(byAdding: .hour, value: 1, to: latest)!
        return start...end
    }

    private var yUpperBound: Int {
        if let noteCount, noteCount > 0 {
            return noteCount * 2
        }
        return max(series.map(\.exScore).max() ?? 1, 1)
    }

    var body: some View {
        Chart {
            ForEach(series) { entry in
                AreaMark(
                    x: .value("Shared.Date", entry.captureDate),
                    y: .value("Shared.Score", entry.exScore)
                )
            }
            if let noteCount, noteCount > 0 {
                let maximum = Float(noteCount * 2)
                djLevelRule("AAA", value: maximum * 8.0 / 9.0, color: .orange, opacity: 0.7)
                djLevelRule("AA", value: maximum * 7.0 / 9.0, color: .gray, opacity: 0.55)
                djLevelRule("A", value: maximum * 6.0 / 9.0, color: .teal, opacity: 0.4)
            }
        }
        .chartXScale(domain: dateRange)
        .chartYScale(domain: 0...yUpperBound)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisTick()
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 200.0)
    }

    private func djLevelRule(
        _ label: String, value: Float, color: Color, opacity: Double
    ) -> some ChartContent {
        RuleMark(y: .value(label, value))
            .foregroundStyle(color)
            .annotation(position: .topLeading,
                        overflowResolution: .init(x: .fit(to: .chart), y: .automatic)) {
                Text(verbatim: label)
                    .foregroundStyle(color.gradient)
                    .font(.caption2)
                    .opacity(opacity)
            }
            .opacity(opacity)
    }
}
