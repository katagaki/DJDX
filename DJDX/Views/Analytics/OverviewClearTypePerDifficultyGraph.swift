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

    @State var legendPosition: AnnotationPosition = .trailing

    var body: some View {
        Chart(graphData[difficulty]?.keys ??
              [], id: \.self) { (clearType) in
            let count = graphData[difficulty]![clearType]!
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
