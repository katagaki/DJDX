//
//  TrendsClearLampGraph.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/23.
//

import Charts
import OrderedCollections
import SwiftUI

struct TrendsClearLampGraph: View {
    @Binding var clearLampPerImportGroup: [Date: [Int: OrderedDictionary<String, Int>]]
    @Binding var selectedDifficulty: Int

    var body: some View {
        Chart(Array(clearLampPerImportGroup.keys).sorted(), id: \.self) { date in
            ForEach(clearLampPerImportGroup[date]![selectedDifficulty]!.keys.reversed(), id: \.self) { clearType in
                let count = clearLampPerImportGroup[date]![selectedDifficulty]![clearType]!
                AreaMark(
                    x: .value("Shared.Date", date),
                    y: .value("Shared.ClearCount", count)
                )
                .foregroundStyle(by: .value("Shared.ClearType", clearType))
            }
        }
        .chartLegend(.visible)
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
