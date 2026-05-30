//
//  TowerDetailView.swift
//  DJDX
//
//  Created by Claude on 2026/05/29.
//

import SwiftUI

struct TowerDetailContainer: View {

    let path: TowerPath

    @State var towerEntries: [IIDXTowerEntry] = []

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
            switch path {
            case .recent:
                TowerDetailView(title: "Tower.ChartMode.Recent", entries: towerEntries) {
                    TowerBarChart(entries: chartEntries)
                }
            case .totals:
                TowerDetailView(title: "Tower.ChartMode.Totals", entries: towerEntries) {
                    TowerTotalsChart(
                        totalKeyCount: totalKeyCount,
                        totalScratchCount: totalScratchCount
                    )
                }
            }
        }
        .task {
            towerEntries = await fetcher.allTowerEntries()
        }
    }
}

struct TowerDetailView<Chart: View>: View {

    let title: LocalizedStringKey
    let entries: [IIDXTowerEntry]
    @ViewBuilder let chart: Chart

    var body: some View {
        List {
            Section {
                chart
                    .frame(height: 240.0)
                    .opacity(entries.isEmpty ? 0.25 : 1.0)
                    .overlay {
                        if entries.isEmpty {
                            Text("Shared.NoData")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            Section {
                ForEach(entries, id: \.playDate) { entry in
                    HStack {
                        Text(entry.playDate, format: .dateTime.year().month().day())
                            .monospacedDigit()
                        Spacer()
                        Text("Count.\(entry.keyCount)")
                            .monospacedDigit()
                            .foregroundStyle(.blue)
                            .frame(width: 80, alignment: .trailing)
                        Text("Count.\(entry.scratchCount)")
                            .monospacedDigit()
                            .foregroundStyle(.red)
                            .frame(width: 80, alignment: .trailing)
                    }
                    .listRowBackground(Color.clear)
                }
            } header: {
                HStack {
                    Text("Tower.Header.PlayDate")
                    Spacer()
                    Text("Shared.IIDX.Keys")
                        .frame(width: 80, alignment: .trailing)
                    Text("Shared.IIDX.Scratch")
                        .frame(width: 80, alignment: .trailing)
                }
            }
        }
        .navigator(title, inline: true)
        .scrollContentBackground(.hidden)
    }
}
