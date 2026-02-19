//
//  TrendsDJLevelGraph.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/07/07.
//

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
                .foregroundStyle(by: .value("Shared.DJLevel", djLevel))
                .interpolationMethod(.monotone)
            }
        }
        .chartForegroundStyleScale([
            "AAA": Color.primary,
            "AA": .orange,
            "A": .yellow,
            "B": .green,
            "C": .teal,
            "D": .blue,
            "E": .indigo,
            "F": .red
        ])
    }
}
