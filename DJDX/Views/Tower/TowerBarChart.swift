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

    var body: some View {
        Chart(entries, id: \.playDate) { entry in
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
        }
    }
}
