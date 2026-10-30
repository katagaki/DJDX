//
//  OverviewDJLevelPieGraph.swift
//  DJDX
//
//  Created on 2026/02/19.
//

import Charts
import SwiftUI

struct OverviewDJLevelPieGraph: View {
    @Binding var graphData: [Int: [IIDXDJLevel: Int]]
    @Binding var difficulty: Int

    var body: some View {
        VStack {
            if let levelData = graphData[difficulty] {
                let filteredData = IIDXDJLevel.sorted.filter { levelData[$0] ?? 0 > 0 }
                if !filteredData.isEmpty {
                    Chart(filteredData, id: \.self) { djLevel in
                        SectorMark(angle: .value(djLevel.rawValue, levelData[djLevel] ?? 0))
                            .foregroundStyle(by: .value("Shared.IIDX.DJLevel", djLevel.rawValue))
                    }
                    .chartForegroundStyleScale(
                        domain: IIDXDJLevel.chartColorDomain,
                        range: IIDXDJLevel.chartColorRange
                    )
                    .chartLegend(.hidden)
                } else {
                    Spacer()
                }
            } else {
                Spacer()
            }
        }
    }
}
