//
//  TowerTotalsChart.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/02/20.
//

import Charts
import SwiftUI

struct TowerTotalsChart: View {
    let totalKeyCount: Int
    let totalScratchCount: Int

    /// 鍵盤タワー: 鍵盤7回分で1cm
    var keyTowerHeight: Double {
        Double(totalKeyCount) / 7.0
    }

    /// スクラッチタワー: スクラッチ1回分で1cm
    var scratchTowerHeight: Double {
        Double(totalScratchCount)
    }

    var body: some View {
        Chart {
            BarMark(
                x: .value("Tower.Type",
                          NSLocalizedString("Tower.Totals.Keys", comment: "")),
                y: .value("Tower.Totals.Height", keyTowerHeight)
            )
            .foregroundStyle(.blue)
            .annotation(position: .top) {
                Text("Tower.Totals.HeightValue.\(Int(keyTowerHeight))")
                    .font(.caption)
                    .monospacedDigit()
            }

            BarMark(
                x: .value("Tower.Type",
                          NSLocalizedString("Tower.Totals.Scratch", comment: "")),
                y: .value("Tower.Totals.Height", scratchTowerHeight)
            )
            .foregroundStyle(.red)
            .annotation(position: .top) {
                Text("Tower.Totals.HeightValue.\(Int(scratchTowerHeight))")
                    .font(.caption)
                    .monospacedDigit()
            }
        }
    }
}
