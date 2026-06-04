import Charts
import OrderedCollections
import SwiftUI

struct OverviewClearTypeOverallGraph: View {
    @Binding var graphData: [Int: OrderedDictionary<String, Int>]

    @State var isInteractive: Bool = false
    var isHorizontal: Bool = false

    var populatedDifficulties: [Int] {
        graphData.filter { _, counts in
            counts.values.contains(where: { $0 > 0 })
        }.keys.sorted()
    }

    // Pad the domain by half a unit on each side so the first and last bars
    // sit fully inside the plot instead of overflowing its edges.
    var levelDomain: ClosedRange<Double> {
        if isInteractive {
            return 0.5...12.5
        }
        guard let first = populatedDifficulties.first,
              let last = populatedDifficulties.last else {
            return 0.5...12.5
        }
        if populatedDifficulties.count == 1 {
            let lower = max(1, first - 1)
            let upper = min(12, first + 1)
            return (Double(lower) - 0.5)...(Double(upper) + 0.5)
        }
        return (Double(first) - 0.5)...(Double(last) + 0.5)
    }

    // Integer level ticks within the (half-unit padded) domain, so each axis
    // label lines up exactly with its bar.
    var axisValues: [Double] {
        let lower = Int(levelDomain.lowerBound.rounded(.up))
        let upper = Int(levelDomain.upperBound.rounded(.down))
        guard lower <= upper else { return [] }
        return (lower...upper).map(Double.init)
    }

    let clearTypeColorScale: KeyValuePairs<String, Color> = [
        "FULLCOMBO CLEAR": .blue,
        "CLEAR": .cyan,
        "EASY CLEAR": .green,
        "ASSIST CLEAR": .purple,
        "HARD CLEAR": .pink,
        "EX HARD CLEAR": .yellow,
        "FAILED": .red
    ]

    var body: some View {
        if isHorizontal {
            horizontalChart
        } else {
            verticalChart
        }
    }

    @ViewBuilder
    var verticalChart: some View {
        Chart(graphData.keys.sorted(), id: \.self) { difficulty in
            ForEach(graphData[difficulty]!.keys.reversed(), id: \.self) { clearType in
                let count = graphData[difficulty]![clearType]!
                BarMark(
                    x: .value("LEVEL", Double(difficulty)),
                    y: .value("Shared.ClearCount", count),
                    width: .inset(8.0),
                    stacking: .standard
                )
                .foregroundStyle(by: .value("Shared.IIDX.ClearType", clearType))
            }
        }
        .chartXAxis {
            AxisMarks(values: axisValues) { value in
                AxisGridLine()
                AxisTick()
                if let level = value.as(Double.self) {
                    AxisValueLabel { Text(verbatim: "\(Int(level))") }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea.padding(.horizontal, 0.0)
        }
        .chartXScale(domain: levelDomain)
        .chartForegroundStyleScale(clearTypeColorScale)
    }

    @ViewBuilder
    var horizontalChart: some View {
        // A horizontal bar needs a categorical axis for the level (the bar's
        // position) and a quantitative axis for the count (its length). Using a
        // quantitative level axis makes Swift Charts fall back to vertical bars.
        Chart(populatedDifficulties, id: \.self) { difficulty in
            ForEach(graphData[difficulty]!.keys.reversed(), id: \.self) { clearType in
                let count = graphData[difficulty]![clearType]!
                BarMark(
                    x: .value("Shared.ClearCount", count),
                    y: .value("LEVEL", "\(difficulty)"),
                    stacking: .standard
                )
                .foregroundStyle(by: .value("Shared.IIDX.ClearType", clearType))
            }
        }
        .chartYScale(domain: populatedDifficulties.map { "\($0)" })
        .chartForegroundStyleScale(clearTypeColorScale)
    }
}
