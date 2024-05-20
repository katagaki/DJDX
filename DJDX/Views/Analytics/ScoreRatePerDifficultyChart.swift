//
//  ScoreRatePerDifficultyChart.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/21.
//

import Charts
import SwiftUI

struct ScoreRatePerDifficultyChart: View {
    @Binding var scoreRatePerDifficulty: [Int: [String: Int]]
    @Binding var djLevels: [String]
    @Binding var selectedDifficulty: Int

    var body: some View {
        Chart(scoreRatePerDifficulty[selectedDifficulty]?.sorted(by: <) ??
              [:].sorted(by: <), id: \.key) { djLevel, count in
            BarMark(
                x: .value("DJ LEVEL", djLevel),
                y: .value("CLEAR COUNT", count),
                width: .fixed(10.0)
            )
        }
              .chartLegend(.visible)
              .chartXScale(domain: djLevels)
    }
}
