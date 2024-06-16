//
//  DJLevelPerDifficultyGraph.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/21.
//

import Charts
import SwiftUI

struct DJLevelPerDifficultyGraph: View {
    @Binding var djLevelPerDifficulty: [Int: [IIDXDJLevel: Int]]
    @Binding var selectedDifficulty: Int

    var body: some View {
        Chart(djLevelPerDifficulty[selectedDifficulty]?.sorted(by: { $0.key < $1.key }) ??
              [:].sorted(by: { $0.key < $1.key }), id: \.key) { djLevel, count in
            BarMark(
                x: .value("Shared.DJLevel", djLevel.rawValue),
                y: .value("Shared.ClearCount", count),
                width: .inset(8.0)
            )
        }
              .chartLegend(.visible)
              .chartXScale(domain: IIDXDJLevel.sortedStrings)
    }
}
