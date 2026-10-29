import Charts
import SwiftUI

struct IIDXProgressGraph: View {
    let points: [IIDXProgressPoint]
    var symbolSize: CGFloat = 30.0

    static let newClearsSeries = "NEW CLEAR"
    static let newHighScoresSeries = "NEW HIGH SCORE"

    var body: some View {
        Chart {
            ForEach(points) { point in
                series(Self.newClearsSeries, date: point.date, count: point.newClears)
                series(Self.newHighScoresSeries, date: point.date, count: point.newHighScores)
            }
        }
        .chartForegroundStyleScale([
            Self.newClearsSeries: AnalyticsCardType.newClearLamps.iconColor,
            Self.newHighScoresSeries: AnalyticsCardType.newScoreUpdates.iconColor
        ])
        .chartSymbolScale([
            Self.newClearsSeries: .circle,
            Self.newHighScoresSeries: .circle
        ])
    }

    @ChartContentBuilder
    func series(_ name: String, date: Date, count: Int) -> some ChartContent {
        LineMark(
            x: .value("Shared.Date", date),
            y: .value("Shared.ClearCount", count)
        )
        .foregroundStyle(by: .value("Analytics.Progress", name))
        .symbol(by: .value("Analytics.Progress", name))
        .symbolSize(symbolSize)
        .interpolationMethod(.monotone)
    }
}

struct IIDXProgressDetailView: View {
    let points: [IIDXProgressPoint]

    var body: some View {
        List {
            if points.isEmpty {
                Text("Analytics.NoData")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    IIDXProgressGraph(points: points)
                        .chartLegend(position: .bottom, alignment: .leading)
                        .frame(height: 240.0)
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(points.reversed()) { point in
                        HStack(spacing: 12.0) {
                            Text(point.date, format: .dateTime.year().month().day())
                                .font(.subheadline)
                            Spacer()
                            count(point.newClears, cardType: .newClearLamps)
                            count(point.newHighScores, cardType: .newScoreUpdates)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    func count(_ value: Int, cardType: AnalyticsCardType) -> some View {
        Label {
            Text(verbatim: "\(value)")
                .font(.subheadline.monospacedDigit().bold())
                .foregroundStyle(value > 0 ? .primary : .secondary)
                .frame(minWidth: 32.0, alignment: .trailing)
        } icon: {
            Image(systemName: cardType.systemImage)
                .foregroundStyle(cardType.iconColor)
        }
        .labelStyle(.titleAndIcon)
    }
}
