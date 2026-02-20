//
//  OverviewClearTypePerDifficultyGraph.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/21.
//

import Charts
import OrderedCollections
import SwiftUI

struct OverviewClearTypePerDifficultyGraph: View {
    @Binding var graphData: [Int: OrderedDictionary<String, Int>]
    @Binding var difficulty: Int

    var body: some View {
        VStack {
            if let clearData = graphData[difficulty], clearData.keys.count > 0 {
                Chart(clearData.keys, id: \.self) { clearType in
                    SectorMark(angle: .value(clearType, clearData[clearType] ?? 0))
                        .foregroundStyle(by: .value("Shared.ClearType", clearType))
                }
                .chartXScale(domain: IIDXClearType.sortedStrings.reversed())
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
