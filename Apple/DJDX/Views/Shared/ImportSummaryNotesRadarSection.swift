import SwiftUI

struct ImportSummaryNotesRadarSection: View {

    let notesRadar: ImportSummaryNotesRadar

    var body: some View {
        VStack(spacing: 12.0) {
            VStack(alignment: .leading, spacing: 4.0) {
                HStack {
                    Text(verbatim: "NOTES RADAR (\(notesRadar.playType))")
                        .font(.radarline(.caption))
                    Spacer()
                    if let previousRadar = notesRadar.previousRadar {
                        Text(verbatim: signed(notesRadar.radar.sum() - previousRadar.sum()))
                            .font(.scoreline(.caption))
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Spacer(minLength: 0.0)
                    Text(verbatim: format(notesRadar.radar.sum()))
                        .font(.scoreline(.largeTitle))
                        .foregroundStyle(notesRadar.radar.color(isPlayerRadar: true).gradient)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            RadarChartView(
                notesRadar.radar,
                isPlayerRadar: true,
                comparison: notesRadar.previousRadar,
                labelFontSize: 8.0,
                lineWidth: 1.5
            )
            .frame(height: 180.0)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4.0)
            Grid(horizontalSpacing: 0.0, verticalSpacing: 12.0) {
                let points = notesRadar.radar.displayPoints()
                GridRow {
                    ForEach(points.prefix(3), id: \.label) { point in
                        pointColumn(point)
                    }
                }
                GridRow {
                    ForEach(points.dropFirst(3), id: \.label) { point in
                        pointColumn(point)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func pointColumn(_ point: RadarPointConfig) -> some View {
        VStack(spacing: 2.0) {
            Text(verbatim: point.label)
                .font(.radarline(size: 10.0))
                .foregroundStyle(point.color)
                .brightness(0.88)
                .shadow(color: point.color, radius: 1.0)
                .shadow(color: point.color, radius: 3.0)
            Text(verbatim: format(point.value))
                .font(.scoreline(.subheadline))
            if let previousValue = previousValue(for: point.label) {
                Text(verbatim: signed(point.value - previousValue))
                    .font(.scoreline(.caption2, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity)
    }

    func previousValue(for label: String) -> Double? {
        notesRadar.previousRadar?.points().first { $0.label == label }?.value
    }

    func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    func signed(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always()))
    }
}
