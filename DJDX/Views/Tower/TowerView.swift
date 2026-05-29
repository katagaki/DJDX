//
//  TowerView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/10/06.
//

import SwiftUI

struct TowerView: View {

    @State var towerEntries: [IIDXTowerEntry] = []

    let fetcher = DataFetcher()

    var totalKeyCount: Int {
        towerEntries.reduce(0) { $0 + $1.keyCount } / 100
    }

    var totalScratchCount: Int {
        towerEntries.reduce(0) { $0 + $1.scratchCount } / 100
    }

    var body: some View {
        Group {
            if towerEntries.isEmpty {
                ContentUnavailableView(
                    "Tower.NoData.Title",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Tower.NoData.Description")
                )
                .frame(maxWidth: .infinity, minHeight: 240.0)
            } else {
                TowerTotalsChart(
                    totalKeyCount: totalKeyCount,
                    totalScratchCount: totalScratchCount
                )
                .frame(height: 240.0)
            }
        }
        .task {
            await reloadTowerEntries()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataMigrationCompleted)) { _ in
            Task { await reloadTowerEntries() }
        }
    }

    func reloadTowerEntries() async {
        towerEntries = await fetcher.allTowerEntries()
        await WidgetDataPublisher.shared.publishTower()
    }
}
