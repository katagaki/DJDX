//
//  OverviewClearLampPerDifficultyGraph.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/21.
//

import Charts
import OrderedCollections
import SwiftUI

struct OverviewClearLampPerDifficultyGraph: View {
    @Binding var clearLampPerDifficulty: [Int: OrderedDictionary<String, Int>]
    @Binding var selectedDifficulty: Int

    @State var legendPosition: AnnotationPosition = .trailing

    var body: some View {
        Chart(clearLampPerDifficulty[selectedDifficulty]?.keys ??
              [], id: \.self) { (clearType) in
            let count = clearLampPerDifficulty[selectedDifficulty]![clearType]!
            SectorMark(angle: .value(clearType, count))
                .foregroundStyle(by: .value("Shared.ClearType", clearType))
        }
              .chartLegend(position: legendPosition, alignment: .leading, spacing: 2.0)
              .chartXScale(domain: IIDXClearType.sortedStrings)
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
