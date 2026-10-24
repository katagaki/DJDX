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
    var height: CGFloat = 180.0
    var isInteractive: Bool = false
    @Binding var selectedDate: Date?

    @State private var samples: [SessionHeartRateSample] = []

    init(session: IIDXPlaySession,
         points: [SessionHeartRatePoint],
         height: CGFloat = 180.0,
         isInteractive: Bool = false,
         selectedDate: Binding<Date?> = .constant(nil)) {
        self.session = session
        self.points = points
        self.height = height
        self.isInteractive = isInteractive
        self._selectedDate = selectedDate
    }

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
        .frame(height: height)
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
        Chart {
            ForEach(samples) { sample in
                LineMark(
                    x: .value("Shared.Date", sample.date),
                    y: .value("Sessions.Detail.HeartRate", sample.bpm)
                )
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 2.0))
                .interpolationMethod(.catmullRom)
            }
            selectionRule
        }
        .chartYScale(domain: domain)
        .chartXAxis { timeAxis }
        .chartOverlay { proxy in scrubOverlay(proxy) }
    }

    private var bandChart: some View {
        Chart {
            ForEach(points) { point in
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
            selectionRule
        }
        .chartYScale(domain: domain)
        .chartXAxis { timeAxis }
        .chartOverlay { proxy in scrubOverlay(proxy) }
    }

    private var timeAxis: some AxisContent {
        AxisMarks { _ in
            AxisGridLine()
            AxisValueLabel(format: .dateTime.hour().minute())
        }
    }

    @ChartContentBuilder
    private var selectionRule: some ChartContent {
        if let selectedDate {
            RuleMark(x: .value("Shared.Date", selectedDate))
                .foregroundStyle(.secondary)
                .lineStyle(StrokeStyle(lineWidth: 1.0, dash: [4.0, 3.0]))
        }
    }

    @ViewBuilder
    private func scrubOverlay(_ proxy: ChartProxy) -> some View {
        if isInteractive {
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        LongPressGesture(minimumDuration: 0.2)
                            .sequenced(before: DragGesture(minimumDistance: 0.0))
                            .onChanged { value in
                                guard case .second(true, let drag?) = value else { return }
                                select(at: drag.location, proxy: proxy, geometry: geometry)
                            }
                            .onEnded { _ in
                                withAnimation(.smooth) { selectedDate = nil }
                            }
                    )
            }
        }
    }

    private func select(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let xPosition = location.x - geometry[plotFrame].origin.x
        guard let date: Date = proxy.value(atX: xPosition) else { return }
        withAnimation(.smooth) { selectedDate = date }
    }
}
