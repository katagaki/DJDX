import SwiftUI

struct TowerDetailContainer: View {

    let path: TowerPath

    @State var towerEntries: [IIDXTowerEntry] = []

    let fetcher = IIDXReader()

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
                TowerDetailView(title: "Shared.IIDX.Tower", entries: towerEntries) {
                    TowerTotalsChart(
                        totalKeyCount: totalKeyCount,
                        totalScratchCount: totalScratchCount
                    )
                }
            }
        }
        .appBackgroundGradient()
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
                    .listRowInsets(EdgeInsets(top: 12.0, leading: 16.0, bottom: 12.0, trailing: 16.0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            Section {
                ForEach(entries, id: \.playDate) { entry in
                    HStack {
                        Text(entry.playDate, format: .dateTime.year().month().day())
                            .monospacedDigit()
                        Spacer()
                        Text(entry.keyCount, format: .number)
                            .font(.scoreline(.body))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(.blue)
                            .frame(width: 100, alignment: .trailing)
                        Text(entry.scratchCount, format: .number)
                            .font(.scoreline(.body))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(.red)
                            .frame(width: 100, alignment: .trailing)
                    }
                    .listRowBackground(Color.clear)
                }
            } header: {
                HStack {
                    Text("Tower.Header.PlayDate")
                    Spacer()
                    Text("Shared.IIDX.Keys")
                        .frame(width: 100, alignment: .trailing)
                    Text("Shared.IIDX.Scratch")
                        .frame(width: 100, alignment: .trailing)
                }
            }
        }
        .listStyle(.plain)
        .navigator(title, inline: true)
        .scrollContentBackground(.hidden)
    }
}
