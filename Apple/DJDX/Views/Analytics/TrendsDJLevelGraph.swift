import Charts
import OrderedCollections
import SwiftUI

struct TrendsDJLevelGraph: View {
    @Binding var graphData: [Date: [Int: OrderedDictionary<String, Int>]]
    @Binding var difficulty: Int

    var body: some View {
        Chart(Array(graphData.keys).sorted(), id: \.self) { date in
            ForEach(graphData[date]![difficulty]!.keys.reversed(), id: \.self) { djLevel in
                let count = graphData[date]![difficulty]![djLevel]!
                AreaMark(
                    x: .value("Shared.Date", date),
                    y: .value("Shared.ClearCount", count)
                )
                .foregroundStyle(by: .value("Shared.IIDX.DJLevel", djLevel))
            }
        }
        .chartForegroundStyleScale(
            domain: IIDXDJLevel.chartColorDomain,
            range: IIDXDJLevel.chartColorRange
        )
    }
}
