import Charts
import OrderedCollections
import SwiftUI

struct OverviewClearTypeOverallGraph: View {
    @Binding var graphData: [Int: OrderedDictionary<String, Int>]

    @State var isInteractive: Bool = false
    var isHorizontal: Bool = false
    var levelLimit: Int?
    var shownLevels: Set<Int> = []

    var hasFullCombo: Bool {
        graphData.values.contains { ($0["FULLCOMBO CLEAR"] ?? 0) > 0 }
    }

    var populatedDifficulties: [Int] {
        graphData.filter { _, counts in
            counts.values.contains(where: { $0 > 0 })
        }.keys.sorted()
    }

    var shownDifficulties: [Int] {
        guard let levelLimit else { return populatedDifficulties }
        if !shownLevels.isEmpty {
            return shownLevels.filter { graphData[$0] != nil }.sorted()
        }
        return Array(populatedDifficulties.suffix(levelLimit))
    }

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

    var axisValues: [Double] {
        let lower = Int(levelDomain.lowerBound.rounded(.up))
        let upper = Int(levelDomain.upperBound.rounded(.down))
        guard lower <= upper else { return [] }
        return (lower...upper).map(Double.init)
    }

    var body: some View {
        if isHorizontal {
            compactRows
        } else {
            verticalChart
        }
    }

    var compactRows: some View {
        let levels = shownDifficulties
        let maxTotal = levels.map { graphData[$0]?.values.reduce(0, +) ?? 0 }.max() ?? 0
        return VStack(alignment: .leading, spacing: 3.0) {
            ForEach(levels, id: \.self) { difficulty in
                HStack(spacing: 6.0) {
                    LevelNumber(level: String(difficulty), size: 10.0)
                        .frame(width: 18.0)
                        .frame(maxHeight: .infinity)
                        .background(
                            LinearGradient(colors: [Color(hex: 0x2A2D33), Color(hex: 0x111215)],
                                           startPoint: .top, endPoint: .bottom),
                            in: .rect(cornerRadius: 3.0)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 3.0).strokeBorder(.white.opacity(0.25), lineWidth: 1.0)
                        }
                    GeometryReader { geometry in
                        HStack(spacing: 0.0) {
                            ForEach(Array((graphData[difficulty] ?? [:]).elements.reversed()), id: \.key) { element in
                                Group {
                                    if element.key == "FULLCOMBO CLEAR" {
                                        FullComboRainbowFill()
                                    } else {
                                        IIDXClearType.color(for: element.key)
                                    }
                                }
                                .frame(width: geometry.size.width * CGFloat(element.value) / CGFloat(max(maxTotal, 1)))
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder
    var verticalChart: some View {
        FullComboRainbowTimeline(isActive: hasFullCombo) { phase in
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
            .chartForegroundStyleScale(
                domain: IIDXClearType.chartColorDomain,
                range: IIDXClearType.chartColorRange(phase: phase)
            )
        }
    }
}
