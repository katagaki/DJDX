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

    @State var clearTypeCounts: OrderedDictionary<String, Int> = [:]

    init(
        graphData: Binding<[Int: OrderedDictionary<String, Int>]>,
        difficulty: Binding<Int>
    ) {
        self._graphData = graphData
        self._difficulty = difficulty
        self.clearTypeCounts = graphData.wrappedValue[difficulty.wrappedValue] ?? [:]
    }

    var body: some View {
        VStack {
            if let clearData = graphData[difficulty], clearData.keys.count > 0 {
                Chart(clearData.keys, id: \.self) { clearType in
                    SectorMark(angle: .value(clearType, clearTypeCounts[clearType] ?? 0))
                        .foregroundStyle(by: .value("Shared.ClearType", clearType))
                }
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
            } else {
                Spacer()
            }
        }
        .onChange(of: graphData) { _, newValue in
            withAnimation(.snappy.speed(2.0)) {
                self.clearTypeCounts = newValue[difficulty] ?? OrderedDictionary<String, Int>()
            }
        }
        .onChange(of: difficulty) { _, newValue in
            withAnimation(.snappy.speed(2.0)) {
                self.clearTypeCounts = graphData[newValue] ?? OrderedDictionary<String, Int>()
            }
        }
    }
}
