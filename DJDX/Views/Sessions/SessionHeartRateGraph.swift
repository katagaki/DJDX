import Charts
import SwiftUI

struct SessionHeartRatePoint: Identifiable {
    let id: String
    let date: Date
    let min: Int
    let max: Int
    var mid: Double { Double(min + max) / 2.0 }
}

struct SessionHeartRateSample: Identifiable {
    var id: Date { date }
    let date: Date
    let bpm: Int
}

struct SessionHeartRateGraph: View {
    let session: IIDXPlaySession
    let points: [SessionHeartRatePoint]

    @State private var samples: [SessionHeartRateSample] = []

    private var domain: ClosedRange<Int> {
        let lows = samples.map(\.bpm) + points.map(\.min)
        let highs = samples.map(\.bpm) + points.map(\.max)
        let low = lows.min() ?? 60
        let high = highs.max() ?? 120
        return Swift.max(0, low - 10)...(high + 10)
    }

    var body: some View {
        Group {
            if samples.isEmpty {
                bandChart
            } else {
                lineChart
            }
        }
        .frame(height: 180.0)
        .task {
            let raw = await IIDXSessionWorkoutBridge.shared.heartRateSamples(
                from: session.startDate,
                to: session.endDate ?? .now
            )
            withAnimation(.smooth) {
                samples = raw.map { SessionHeartRateSample(date: $0.date, bpm: $0.bpm) }
            }
        }
    }

    private var lineChart: some View {
        Chart(samples) { sample in
            LineMark(
                x: .value("Shared.Date", sample.date),
                y: .value("Sessions.Detail.HeartRate", sample.bpm)
            )
            .foregroundStyle(.red)
            .lineStyle(StrokeStyle(lineWidth: 2.0))
            .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: domain)
        .chartXAxis { timeAxis }
    }

    private var bandChart: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("Shared.Date", point.date),
                yStart: .value("Sessions.Detail.HeartRate", point.min),
                yEnd: .value("Sessions.Detail.HeartRate", point.max)
            )
            .foregroundStyle(.red.opacity(0.12))
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Shared.Date", point.date),
                y: .value("Sessions.Detail.HeartRate", point.mid)
            )
            .foregroundStyle(.red)
            .lineStyle(StrokeStyle(lineWidth: 2.0))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Shared.Date", point.date),
                y: .value("Sessions.Detail.HeartRate", point.mid)
            )
            .foregroundStyle(.red)
            .symbolSize(24.0)
        }
        .chartYScale(domain: domain)
        .chartXAxis { timeAxis }
    }

    private var timeAxis: some AxisContent {
        AxisMarks { _ in
            AxisGridLine()
            AxisValueLabel(format: .dateTime.hour().minute())
        }
    }
}
