//
//  ClearLampPerDifficultyGraph.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/21.
//

import Charts
import SwiftUI

struct ClearLampPerDifficultyGraph: View {
    @Binding var clearLampPerDifficulty: [Int: [String: Int]]
    @Binding var selectedDifficulty: Int

    @State var legendPosition: AnnotationPosition = .trailing

    var body: some View {
        Chart(clearLampPerDifficulty[selectedDifficulty]?.sorted(by: <) ??
              [:].sorted(by: <), id: \.key) { clearType, count in
            SectorMark(angle: .value(clearType, count))
                .foregroundStyle(
                    by: .value("CLEAR TYPE", clearType)
                )
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
