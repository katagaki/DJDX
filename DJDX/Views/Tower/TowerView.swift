//
//  TowerView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/10/06.
//

import SwiftUI

struct TowerView: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @State var towerEntries: [IIDXTowerEntry] = []

    var towerNamespace: Namespace.ID

    let fetcher = DataFetcher()

    var chartEntries: [IIDXTowerEntry] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        let recentEntries = towerEntries.prefix(while: { $0.playDate >= thirtyDaysAgo })
        if recentEntries.count >= 5 {
            return Array(recentEntries).reversed()
        }
        return Array(towerEntries.prefix(5)).reversed()
    }

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
                VStack(spacing: 12.0) {
                    Button {
                        navigationManager.push(TowerPath.recent)
                    } label: {
                        AnalyticsCardView(title: "Tower.ChartMode.Recent",
                                          systemImage: "chart.bar.xaxis",
                                          iconColor: .blue,
                                          contentHeight: 200.0) {
                            TowerBarChart(entries: chartEntries)
                        }
                    }
                    .buttonStyle(AnalyticsCardButtonStyle())
                    .automaticMatchedTransitionSource(id: "Tower.Recent", in: towerNamespace)

                    Button {
                        navigationManager.push(TowerPath.totals)
                    } label: {
                        AnalyticsCardView(title: "Tower.ChartMode.Totals",
                                          systemImage: "building.2",
                                          iconColor: .orange,
                                          contentHeight: 200.0) {
                            TowerTotalsChart(
                                totalKeyCount: totalKeyCount,
                                totalScratchCount: totalScratchCount
                            )
                        }
                    }
                    .buttonStyle(AnalyticsCardButtonStyle())
                    .automaticMatchedTransitionSource(id: "Tower.Totals", in: towerNamespace)
                }
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
