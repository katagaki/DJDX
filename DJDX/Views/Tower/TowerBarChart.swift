//
//  TowerBarChart.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/02/20.
//

import Charts
import SwiftUI

struct TowerBarChart: View {
    let entries: [IIDXTowerEntry]
    var usesDateAxis: Bool = true

    var body: some View {
        Chart(Array(entries.enumerated()), id: \.element.playDate) { index, entry in
            if usesDateAxis {
                BarMark(
                    x: .value("Tower.Header.PlayDate",
                              entry.playDate, unit: .day),
                    y: .value("Shared.IIDX.Keys", entry.keyCount)
                )
                .foregroundStyle(.blue)
                .position(by: .value("Tower.Type", "Keys"))

                BarMark(
                    x: .value("Tower.Header.PlayDate",
                              entry.playDate, unit: .day),
                    y: .value("Shared.IIDX.Scratch", entry.scratchCount)
                )
                .foregroundStyle(.red)
                .position(by: .value("Tower.Type", "Scratch"))
            } else {
                BarMark(
                    x: .value("Tower.Header.PlayDate", index),
                    y: .value("Shared.IIDX.Keys", entry.keyCount)
                )
                .foregroundStyle(.blue)
                .position(by: .value("Tower.Type", "Keys"))

                BarMark(
                    x: .value("Tower.Header.PlayDate", index),
                    y: .value("Shared.IIDX.Scratch", entry.scratchCount)
                )
                .foregroundStyle(.red)
                .position(by: .value("Tower.Type", "Scratch"))
            }
        }
    }
}
