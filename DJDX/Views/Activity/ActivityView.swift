//
//  ActivityView.swift
//  DJDX
//
//  Created by Claude on 2026/05/29.
//

import SwiftUI

struct ActivityView: View {

    @State var towerEntries: [IIDXTowerEntry] = []
    @State var isShowingEntries: Bool = false

    let fetcher = DataFetcher()

    var chartEntries: [IIDXTowerEntry] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        let recentEntries = towerEntries.prefix(while: { $0.playDate >= thirtyDaysAgo })
        if recentEntries.count >= 5 {
            return Array(recentEntries).reversed()
        }
        return Array(towerEntries.prefix(5)).reversed()
    }

    var recentEntries: [IIDXTowerEntry] {
        Array(towerEntries.prefix(5))
    }

    var body: some View {
        Group {
            if towerEntries.isEmpty {
                ContentUnavailableView(
                    "Activity.NoData.Title",
                    systemImage: "calendar",
                    description: Text("Activity.NoData.Description")
                )
                .frame(maxWidth: .infinity, minHeight: 240.0)
            } else {
                Group {
                    if isShowingEntries {
                        entryList
                    } else {
                        TowerBarChart(entries: chartEntries)
                            .frame(height: 240.0)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .onTapGesture {
                    withAnimation(.smooth) {
                        isShowingEntries.toggle()
                    }
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

    @ViewBuilder
    var entryList: some View {
        VStack(spacing: 8.0) {
            HStack {
                Text("Tower.Header.PlayDate")
                Spacer()
                Text("Shared.IIDX.Keys")
                    .frame(width: 80, alignment: .trailing)
                Text("Shared.IIDX.Scratch")
                    .frame(width: 80, alignment: .trailing)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            ForEach(recentEntries, id: \.playDate) { entry in
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
            }
        }
        .frame(minHeight: 240.0)
    }

    func reloadTowerEntries() async {
        towerEntries = await fetcher.allTowerEntries()
    }
}
