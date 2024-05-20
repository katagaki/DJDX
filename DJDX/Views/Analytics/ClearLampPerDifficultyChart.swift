//
//  ClearLampPerDifficultyChart.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/21.
//

import Charts
import SwiftUI

struct ClearLampPerDifficultyChart: View {
    @Binding var clearLampPerDifficulty: [Int: [String: Int]]
    @Binding var clearTypes: [String]
    @Binding var selectedDifficulty: Int

    var body: some View {
        Chart(clearLampPerDifficulty[selectedDifficulty]?.sorted(by: <) ??
              [:].sorted(by: <), id: \.key) { clearType, count in
            SectorMark(angle: .value(clearType, count))
                .foregroundStyle(
                    by: .value("CLEAR TYPE", clearType)
                )
        }
        .chartLegend(.visible)
        .chartXScale(domain: clearTypes)
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
