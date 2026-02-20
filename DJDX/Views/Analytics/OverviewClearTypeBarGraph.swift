//
//  OverviewClearTypeBarGraph.swift
//  DJDX
//
//  Created on 2026/02/19.
//

import Charts
import OrderedCollections
import SwiftUI

struct OverviewClearTypeBarGraph: View {
    @Binding var graphData: [Int: OrderedDictionary<String, Int>]
    @Binding var difficulty: Int

    var body: some View {
        VStack {
            if let clearData = graphData[difficulty], clearData.keys.count > 0 {
                Chart(clearData.keys, id: \.self) { clearType in
                    BarMark(
                        x: .value("Shared.ClearType", clearType),
                        y: .value("Shared.ClearCount", clearData[clearType] ?? 0),
                        width: .inset(8.0)
                    )
                    .foregroundStyle(by: .value("Shared.ClearType", clearType))
                }
                .chartXScale(domain: IIDXClearType.sortedStringsWithoutNoPlay.reversed())
                .chartForegroundStyleScale([
                    "FULLCOMBO CLEAR": .blue,
                    "CLEAR": .cyan,
                    "EASY CLEAR": .green,
                    "ASSIST CLEAR": .purple,
                    "HARD CLEAR": .pink,
                    "EX HARD CLEAR": .yellow,
                    "FAILED": .red
                ])
            } else {
                Spacer()
            }
        }
    }
}
