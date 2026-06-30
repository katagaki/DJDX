import SwiftUI

struct SessionHeartRateDetailView: View {
    let session: IIDXPlaySession
    let plays: [IIDXCapturedPlay]

    @State private var samples: [SessionHeartRateSample] = []
    @State private var selectedDate: Date?

    private let window: TimeInterval = 90.0

    var body: some View {
        ScrollView {
            VStack(spacing: 20.0) {
                overviewSection
                graphSection
                breakdownSection
            }
            .padding(.vertical, 8.0)
        }
        .scrollContentBackground(.hidden)
        .background {
            LinearGradient(
                colors: [.backgroundGradientTop, .backgroundGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .navigationTitle("Sessions.Detail.HeartRate")
        .navigationBarTitleDisplayMode(.inline)
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

    @ViewBuilder
    private var overviewSection: some View {
        if let stats = overviewStats {
            HStack(spacing: 0.0) {
                statColumn("Sessions.HeartRate.Average", value: stats.average)
                statColumn("Sessions.HeartRate.Minimum", value: stats.minimum)
                statColumn("Sessions.HeartRate.Maximum", value: stats.maximum)
            }
            .padding(.horizontal)
        }
    }

    private var graphSection: some View {
        SessionHeartRateGraph(
            session: session,
            points: points,
            height: 280.0,
            isInteractive: true,
            selectedDate: $selectedDate
        )
        .padding(.horizontal)
    }

    @ViewBuilder
    private var breakdownSection: some View {
        let stats = chartStats
        if !stats.isEmpty {
            let visible = collapsed(stats)
            VStack(spacing: 12.0) {
                AnalyticsSectionHeader(title: "Sessions.HeartRate.ByChart")
                VStack(spacing: 0.0) {
                    ForEach(visible) { stat in
                        chartRow(stat)
                        if stat.id != visible.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func collapsed(_ stats: [ChartHeartRate]) -> [ChartHeartRate] {
        guard let selectedDate else { return stats }
        guard let nearest = stats.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }) else { return stats }
        return [nearest]
    }

    private func chartRow(_ stat: ChartHeartRate) -> some View {
        VStack(alignment: .leading, spacing: 8.0) {
            HStack {
                Text(verbatim: stat.title)
                    .bold()
                    .fontWidth(.condensed)
                    .lineLimit(1)
                Spacer(minLength: 8.0)
                Text(stat.date, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 0.0) {
                statColumn("Sessions.HeartRate.Average", value: stat.average)
                statColumn("Sessions.HeartRate.Minimum", value: stat.min)
                statColumn("Sessions.HeartRate.Maximum", value: stat.max)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12.0)
    }

    private func statColumn(_ titleKey: LocalizedStringKey, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2.0) {
            Text(titleKey)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(verbatim: "\(value)")
                .font(.title3.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var points: [SessionHeartRatePoint] {
        plays.compactMap { play in
            guard let min = play.minHeartRate, let max = play.maxHeartRate else { return nil }
            return SessionHeartRatePoint(id: play.id, date: play.captureDate, min: min, max: max)
        }
        .sorted { $0.date < $1.date }
    }

    private var overviewStats: HeartRateOverview? {
        if !samples.isEmpty {
            let bpms = samples.map(\.bpm)
            let average = Int((Double(bpms.reduce(0, +)) / Double(bpms.count)).rounded())
            return HeartRateOverview(average: average, minimum: bpms.min() ?? average, maximum: bpms.max() ?? average)
        }
        let snapshots = points
        guard !snapshots.isEmpty else { return nil }
        let mids = snapshots.map(\.mid)
        let average = Int((mids.reduce(0.0, +) / Double(mids.count)).rounded())
        return HeartRateOverview(
            average: average,
            minimum: snapshots.map(\.min).min() ?? average,
            maximum: snapshots.map(\.max).max() ?? average
        )
    }

    private var chartStats: [ChartHeartRate] {
        plays
            .sorted { $0.captureDate < $1.captureDate }
            .compactMap { play in
                let start = play.captureDate.addingTimeInterval(-window)
                let bpms = samples
                    .filter { $0.date >= start && $0.date <= play.captureDate }
                    .map(\.bpm)
                guard !bpms.isEmpty else { return nil }
                let average = Int((Double(bpms.reduce(0, +)) / Double(bpms.count)).rounded())
                return ChartHeartRate(
                    id: play.id,
                    title: play.songTitle ?? String(localized: "Sessions.UnknownSong"),
                    date: play.captureDate,
                    average: average,
                    min: bpms.min() ?? average,
                    max: bpms.max() ?? average
                )
            }
    }
}

private struct HeartRateOverview {
    let average: Int
    let minimum: Int
    let maximum: Int
}

private struct ChartHeartRate: Identifiable {
    let id: String
    let title: String
    let date: Date
    let average: Int
    let min: Int
    let max: Int
}
