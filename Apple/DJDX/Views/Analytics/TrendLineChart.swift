import Charts
import SwiftUI

struct TrendLineChart: View {
    let points: [TrendPoint]
    let color: Color
    var showsPoints: Bool = false

    var yDomain: ClosedRange<Double> {
        let values = points.map(\.value)
        let minimum = values.min() ?? 0.0
        let maximum = values.max() ?? 1.0
        let padding = max((maximum - minimum) * 0.1, maximum * 0.01, 0.01)
        return max(minimum - padding, 0.0)...(maximum + padding)
    }

    var body: some View {
        Chart(points) { point in
            AreaMark(x: .value("Shared.Date", point.date),
                     yStart: .value("Shared.Score", yDomain.lowerBound),
                     yEnd: .value("Shared.Score", point.value))
                .foregroundStyle(color.opacity(0.2).gradient)
            LineMark(x: .value("Shared.Date", point.date),
                     y: .value("Shared.Score", point.value))
                .foregroundStyle(color)
            if showsPoints || points.count == 1 {
                PointMark(x: .value("Shared.Date", point.date),
                          y: .value("Shared.Score", point.value))
                    .foregroundStyle(color)
                    .symbolSize(20.0)
            }
        }
        .chartYScale(domain: yDomain)
        .chartPlotStyle { $0.clipped() }
    }
}

struct TrendCardContent: View {
    let points: [TrendPoint]
    let color: Color
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 4.0) {
            Text(verbatim: points.last.map { format($0.value) } ?? "-")
                .font(.scoreline(size: 20.0))
                .fontWidth(.standard)
                .foregroundStyle(points.isEmpty ? .secondary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            TrendLineChart(points: points, color: color)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .opacity(points.isEmpty ? 0.25 : 1.0)
                .overlay {
                    if points.isEmpty {
                        Text("Shared.NoData")
                            .emptyLabel()
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
        }
    }
}

struct TrendDetailView: View {
    let points: [TrendPoint]
    let color: Color
    let format: (Double) -> String

    var body: some View {
        List {
            if points.isEmpty {
                Text("Analytics.NoData")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    TrendLineChart(points: points, color: color, showsPoints: true)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                                AxisGridLine()
                                if let date = value.as(Date.self) {
                                    AxisValueLabel {
                                        Text(date, format: .dateTime.month().day())
                                    }
                                }
                            }
                        }
                        .frame(height: 240.0)
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(Array(points.enumerated().reversed()), id: \.element.id) { index, point in
                        HStack {
                            Text(point.date, format: .dateTime.year().month().day())
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            if index > 0 {
                                deltaText(point.value - points[index - 1].value)
                            }
                            Text(verbatim: format(point.value))
                                .font(.subheadline.weight(.heavy))
                                .fontWidth(.expanded)
                                .monospacedDigit()
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    func deltaText(_ delta: Double) -> some View {
        if delta != 0.0 {
            Text(verbatim: (delta > 0.0 ? "+" : "-") + format(abs(delta)))
                .font(.caption.weight(.semibold))
                .foregroundStyle(delta > 0.0 ? .green : .red)
                .monospacedDigit()
        }
    }
}
