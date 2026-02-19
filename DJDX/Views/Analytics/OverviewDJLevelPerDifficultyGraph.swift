//
//  OverviewDJLevelPerDifficultyGraph.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/21.
//

import Charts
import SwiftUI

struct OverviewDJLevelPerDifficultyGraph: View {
    @Binding var graphData: [Int: [IIDXDJLevel: Int]]
    @Binding var difficulty: Int

    static let visibleLevels: [IIDXDJLevel] = [.djC, .djB, .djA, .djAA, .djAAA]
    static let visibleLevelStrings: [String] = visibleLevels.map { $0.rawValue }

    var filteredData: [(key: IIDXDJLevel, value: Int)] {
        let data = graphData[difficulty] ?? [:]
        return Self.visibleLevels.map { level in
            (key: level, value: data[level] ?? 0)
        }
    }

    var body: some View {
        Chart(filteredData, id: \.key) { djLevel, count in
            BarMark(
                x: .value("Shared.DJLevel", djLevel.rawValue),
                y: .value("Shared.ClearCount", count),
                width: .inset(8.0)
            )
            .foregroundStyle(by: .value("Shared.DJLevel", djLevel.rawValue))
        }
              .chartXScale(domain: Self.visibleLevelStrings)
              .chartForegroundStyleScale([
                "AAA": Color.primary,
                "AA": .orange,
                "A": .yellow,
                "B": .green,
                "C": .teal
              ])
    }
}
