import Charts
import OrderedCollections
import SwiftUI

struct DDRAnalyticsDestinationView: View {

    @Bindable var model: DDRAnalyticsModel
    let path: DDRAnalyticsPath
    var namespace: Namespace.ID

    var body: some View {
        Group {
            switch path {
            case .clearBreakdownDetail:
                DDRClearBreakdownDetailView(clearTypePerLevel: model.clearTypePerLevel)
                    .navigationTitle("Analytics.DDR.ClearBreakdown")
                    .automaticNavigationTransition(id: "DDR.clearBreakdown", in: namespace)
            case .rankBreakdownDetail:
                DDRRankBreakdownDetailView(rankPerDifficulty: model.rankPerDifficulty)
                    .navigationTitle("Analytics.DDR.RankBreakdown")
                    .automaticNavigationTransition(id: "DDR.rankBreakdown", in: namespace)
            }
        }
        .appBackgroundGradient()
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DDRClearBreakdownDetailView: View {
    let clearTypePerLevel: [Int: OrderedDictionary<String, Int>]

    var populatedLevels: [Int] {
        clearTypePerLevel.filter { _, counts in
            counts.values.contains(where: { $0 > 0 })
        }.keys.sorted()
    }

    var body: some View {
        List {
            if populatedLevels.isEmpty {
                Text("Analytics.NoData")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(populatedLevels, id: \.self) { level in
                        DDRClearTypeLevelRow(counts: clearTypePerLevel[level] ?? [:], level: level)
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Shared.Level")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

struct DDRClearTypeLevelRow: View {
    let counts: OrderedDictionary<String, Int>
    let level: Int

    var total: Int { counts.values.reduce(0, +) }

    var segments: [(type: String, count: Int)] {
        DDRSongRecord.clearBreakdownOrder.compactMap { type in
            let count = counts[type] ?? 0
            return count > 0 ? (type, count) : nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6.0) {
            HStack {
                Text(verbatim: "LEVEL \(level)")
                    .font(.subheadline.bold())
                Spacer()
                Text("Shared.SongCount.\(total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            GeometryReader { geometry in
                HStack(spacing: 0.0) {
                    ForEach(segments, id: \.type) { segment in
                        DDRSongRecord.clearColor(for: segment.type)
                            .frame(width: geometry.size.width * CGFloat(segment.count) / CGFloat(max(total, 1)))
                    }
                }
                .clipShape(.rect(cornerRadius: 4.0))
            }
            .frame(height: 16.0)
        }
        .padding(.vertical, 4.0)
    }
}

struct DDRRankBreakdownDetailView: View {
    let rankPerDifficulty: [DDRDifficulty: OrderedDictionary<String, Int>]

    var populatedDifficulties: [DDRDifficulty] {
        DDRDifficulty.sorted.filter { difficulty in
            (rankPerDifficulty[difficulty]?.values.contains(where: { $0 > 0 })) ?? false
        }
    }

    var body: some View {
        List {
            if populatedDifficulties.isEmpty {
                Text("Analytics.NoData")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(populatedDifficulties, id: \.self) { difficulty in
                    Section {
                        Chart(rankElements(for: difficulty), id: \.key) { element in
                            BarMark(
                                x: .value("Rank", DDRSongRecord.rankDisplay(forStem: element.key)),
                                y: .value("Shared.ClearCount", element.value)
                            )
                            .foregroundStyle(DDRSongRecord.rankColor(forStem: element.key))
                        }
                        .frame(height: 140.0)
                        .listRowBackground(Color.clear)
                    } header: {
                        Text(verbatim: difficulty.rawValue)
                            .foregroundStyle(difficulty.color)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    func rankElements(for difficulty: DDRDifficulty) -> [(key: String, value: Int)] {
        let counts = rankPerDifficulty[difficulty] ?? [:]
        return DDRSongRecord.rankOrder.compactMap { rank in
            let count = counts[rank] ?? 0
            return count > 0 ? (rank, count) : nil
        }
    }
}
