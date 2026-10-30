import Charts
import OrderedCollections
import SwiftUI

struct OverviewClearTypePerDifficultyGraph: View {
    @Binding var graphData: [Int: OrderedDictionary<String, Int>]
    @Binding var difficulty: Int

    var body: some View {
        VStack {
            if let clearData = graphData[difficulty], clearData.keys.count > 0 {
                FullComboRainbowTimeline(isActive: (clearData["FULLCOMBO CLEAR"] ?? 0) > 0) { phase in
                    Chart(clearData.keys, id: \.self) { clearType in
                        SectorMark(angle: .value(clearType, clearData[clearType] ?? 0))
                            .foregroundStyle(by: .value("Shared.IIDX.ClearType", clearType))
                    }
                    .chartXScale(domain: IIDXClearType.sortedStrings.reversed())
                    .chartForegroundStyleScale(
                        domain: IIDXClearType.chartColorDomain,
                        range: IIDXClearType.chartColorRange(phase: phase)
                    )
                    .chartLegend(.hidden)
                }
            } else {
                Spacer()
            }
        }
    }
}
