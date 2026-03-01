//
//  WidgetTowerChart.swift
//  Widgets
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import Charts
import SwiftUI

struct WidgetTowerChart: View {
    let totalKeyCount: Int
    let totalScratchCount: Int

    var keyTowerHeight: Double {
        Double(totalKeyCount) / 7.0
    }

    var scratchTowerHeight: Double {
        Double(totalScratchCount)
    }

    var body: some View {
        Chart {
            BarMark(
                x: .value("Type", NSLocalizedString("Tower.Totals.Keys", comment: "")),
                y: .value("Height", keyTowerHeight)
            )
            .foregroundStyle(.blue)

            BarMark(
                x: .value("Type", NSLocalizedString("Tower.Totals.Scratch", comment: "")),
                y: .value("Height", scratchTowerHeight)
            )
            .foregroundStyle(.red)
        }
        .chartLegend(.hidden)
        .widgetAccentable(false)
    }
}
