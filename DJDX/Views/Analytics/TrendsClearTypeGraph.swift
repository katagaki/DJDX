//
//  TrendsClearTypeGraph.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/23.
//

import Charts
import OrderedCollections
import SwiftUI

struct TrendsClearTypeGraph: View {
    @Binding var graphData: [Date: [Int: OrderedDictionary<String, Int>]]
    @Binding var difficulty: Int

    var body: some View {
        Chart(Array(graphData.keys).sorted(), id: \.self) { date in
            ForEach(graphData[date]![difficulty]!.keys.reversed(), id: \.self) { clearType in
                let count = graphData[date]![difficulty]![clearType]!
                AreaMark(
                    x: .value("Shared.Date", date),
                    y: .value("Shared.ClearCount", count)
                )
                .foregroundStyle(by: .value("Shared.ClearType", clearType))
                .interpolationMethod(.monotone)
            }
        }
        .chartForegroundStyleScale([
            "FULLCOMBO CLEAR": .blue,
            "CLEAR": .cyan,
            "ASSIST CLEAR": .purple,
            "EASY CLEAR": .green,
            "HARD CLEAR": .pink,
            "EX HARD CLEAR": .yellow,
            "FAILED": .red
        ])
    }
}
