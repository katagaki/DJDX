import Charts
import SwiftUI

struct ScoreHistoryThreshold: Identifiable {
    let label: String
    let value: Double
    let color: Color
    let opacity: Double

    var id: String { label }
}

struct ScoreHistoryRows: View {

    var history: [Date: Int]
    var yDomain: ClosedRange<Double>
    var thresholds: [ScoreHistoryThreshold] = []

    @State private var isShowingHistory: Bool = false

    var body: some View {
        if history.count >= 2 {
            Button {
                withAnimation(.smooth.speed(2.0)) {
                    isShowingHistory.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    Text("Scores.Viewer.ShowHistory")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isShowingHistory ? 90.0 : 0.0))
                        .foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            if isShowingHistory {
                ScoreHistoryChart(history: history, yDomain: yDomain, thresholds: thresholds)
                    .listRowInsets(.init(top: 18.0, leading: 20.0, bottom: 18.0, trailing: 20.0))
            }
        }
    }
}

struct ScoreHistoryChart: View {

    var history: [Date: Int]
    var yDomain: ClosedRange<Double>
    var thresholds: [ScoreHistoryThreshold] = []

    var sortedHistory: [(key: Date, value: Int)] {
        history.sorted { $0.key < $1.key }
    }

    var dateDomain: ClosedRange<Date> {
        let dates = history.keys
        let earliest = dates.min() ?? .now
        let latest = dates.max() ?? .now
        return Calendar.current.date(byAdding: .day, value: -1, to: earliest)!
            ... Calendar.current.date(byAdding: .day, value: 1, to: latest)!
    }

    var body: some View {
        Chart {
            ForEach(sortedHistory, id: \.key) { date, score in
                AreaMark(x: .value("Shared.Date", date),
                         yStart: .value("Shared.Score", yDomain.lowerBound),
                         yEnd: .value("Shared.Score", Double(score)))
            }
            ForEach(thresholds.filter { yDomain.contains($0.value) }) { threshold in
                RuleMark(y: .value(threshold.label, threshold.value))
                    .foregroundStyle(threshold.color)
                    .annotation(position: .topLeading,
                                overflowResolution: .init(x: .fit(to: .chart), y: .automatic)) {
                        Text(verbatim: threshold.label)
                            .foregroundStyle(threshold.color.gradient)
                            .font(.caption2)
                            .opacity(threshold.opacity)
                    }
                    .opacity(threshold.opacity)
            }
        }
        .chartXScale(domain: dateDomain)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisTick()
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date, format: .dateTime.year(.twoDigits).month(.abbreviated))
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .chartPlotStyle { $0.clipped() }
        .frame(height: 200.0)
    }

    static func zoomedDomain(for history: [Date: Int], step: Int, upperBound: Int) -> ClosedRange<Double> {
        let minimum = history.values.min() ?? 0
        let lowerBound = max((minimum / step - 1) * step, 0)
        return Double(min(lowerBound, upperBound - step))...Double(upperBound)
    }
}
