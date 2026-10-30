import Charts
import OrderedCollections
import SwiftUI

struct TrendsClearTypeGraph: View {
    @Binding var graphData: [Date: [Int: OrderedDictionary<String, Int>]]
    @Binding var difficulty: Int

    var hasFullCombo: Bool {
        graphData.values.contains { ($0[difficulty]?["FULLCOMBO CLEAR"] ?? 0) > 0 }
    }

    var body: some View {
        FullComboRainbowTimeline(isActive: hasFullCombo) { phase in
            Chart(Array(graphData.keys).sorted(), id: \.self) { date in
                ForEach(graphData[date]![difficulty]!.keys.reversed(), id: \.self) { clearType in
                    let count = graphData[date]![difficulty]![clearType]!
                    AreaMark(
                        x: .value("Shared.Date", date),
                        y: .value("Shared.ClearCount", count)
                    )
                    .foregroundStyle(by: .value("Shared.IIDX.ClearType", clearType))
                }
            }
            .chartForegroundStyleScale(
                domain: IIDXClearType.chartColorDomain,
                range: IIDXClearType.chartStyleRange(phase: phase)
            )
        }
    }
}
