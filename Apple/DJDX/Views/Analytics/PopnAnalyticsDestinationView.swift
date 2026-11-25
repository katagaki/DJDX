import OrderedCollections
import SwiftUI

struct PopnAnalyticsDestinationView: View {

    @Bindable var model: PopnAnalyticsModel
    let path: PopnAnalyticsPath
    var namespace: Namespace.ID

    var body: some View {
        Group {
            switch path {
            case .popnClassDetail:
                PopnClassDetailView(model: model)
                    .navigationTitle("Shared.Popn.PopnClass")
                    .automaticNavigationTransition(id: "Popn.popnClass", in: namespace)
            case .medalBreakdownDetail:
                PopnLevelBreakdownDetailView(
                    countsPerLevel: model.clearTypePerLevel,
                    keys: PopnClearType.sortedStringsWithoutNoPlay,
                    color: { PopnClearType(rawValue: $0)?.color ?? .gray },
                    label: { PopnClearType(rawValue: $0)?.abbreviation ?? $0 }
                )
                .navigationTitle("Analytics.Popn.MedalBreakdown")
                .automaticNavigationTransition(id: "Popn.medalBreakdown", in: namespace)
            case .rankBreakdownDetail:
                PopnLevelBreakdownDetailView(
                    countsPerLevel: model.rankPerLevel,
                    keys: PopnRank.sortedStrings,
                    color: { PopnRank(rawValue: $0)?.color ?? .gray },
                    label: { $0 }
                )
                .navigationTitle("Analytics.Popn.RankBreakdown")
                .automaticNavigationTransition(id: "Popn.rankBreakdown", in: namespace)
            case .newHighScoresDetail:
                PopnNewHighScoresDetailView(newHighScores: model.newHighScores)
                    .navigationTitle("Analytics.NewHighScores")
                    .automaticNavigationTransition(id: "Popn.newHighScores", in: namespace)
            case .newClearsDetail(let clearType):
                PopnNewClearsDetailView(newClears: model.newClears[clearType] ?? [])
                    .navigationTitle(Text(verbatim: clearType))
                    .automaticNavigationTransition(id: transitionID(forClearType: clearType), in: namespace)
            case .newRanksDetail(let rank):
                PopnNewRanksDetailView(newRanks: model.newRanks[rank] ?? [])
                    .navigationTitle(Text(verbatim: rank))
                    .automaticNavigationTransition(id: transitionID(forRank: rank), in: namespace)
            }
        }
        .appBackgroundGradient()
        .navigationBarTitleDisplayMode(.inline)
    }

    func transitionID(forClearType clearType: String) -> String {
        switch PopnClearType(rawValue: clearType) {
        case .clear: return "Popn.newClearClear"
        case .fullCombo: return "Popn.newClearFullCombo"
        case .perfect: return "Popn.newClearPerfect"
        default: return "Popn.newClears"
        }
    }

    func transitionID(forRank rank: String) -> String {
        switch PopnRank(rawValue: rank) {
        case .s: return "Popn.newRankS"
        case .aaa: return "Popn.newRankAAA"
        case .aa: return "Popn.newRankAA"
        default: return "Popn.newRanks"
        }
    }
}

// MARK: - Shared

struct PopnLevelLabel: View {
    let difficulty: PopnDifficulty
    let level: Int

    var body: some View {
        VStack(spacing: 1.0) {
            Text(verbatim: difficulty.rawValue)
                .font(.system(size: 10.0).weight(.black))
                .foregroundStyle(difficulty.color)
            Text(verbatim: level > 0 ? "\(level)" : "-")
                .font(.system(size: 18.0).weight(.heavy))
                .fontWidth(.condensed)
                .monospacedDigit()
        }
        .padding([.top, .bottom], 6.0)
        .frame(width: 78.0, alignment: .center)
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 6.0))
    }
}

private struct PopnRankText: View {
    @Environment(\.colorScheme) private var colorScheme
    let rank: String
    var strikethrough: Bool = false

    var body: some View {
        let rankEnum = PopnRank(rawValue: rank) ?? .none
        Group {
            if strikethrough {
                Text(verbatim: rank)
                    .strikethrough()
                    .foregroundStyle(.secondary)
            } else {
                Text(verbatim: rank)
                    .foregroundStyle(AnyShapeStyle(rankEnum.style(colorScheme: colorScheme)))
            }
        }
        .font(.caption.weight(.semibold))
        .fontWidth(.expanded)
    }
}

private struct PopnEntryRow<Detail: View>: View {
    let title: String
    let difficulty: PopnDifficulty
    let level: Int
    @ViewBuilder var detail: Detail

    var body: some View {
        HStack(alignment: .center, spacing: 8.0) {
            VStack(alignment: .leading, spacing: 2.0) {
                Text(title)
                    .bold()
                    .fontWidth(.condensed)
                detail
            }
            Spacer(minLength: 0.0)
            PopnLevelLabel(difficulty: difficulty, level: level)
        }
        .padding(.vertical, 2.0)
        .listRowBackground(Color.clear)
    }
}

private struct PopnDetailList<Content: View>: View {
    let isEmpty: Bool
    @ViewBuilder var content: Content

    var body: some View {
        List {
            if isEmpty {
                Text("Analytics.NoData")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                content
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Overview detail views

struct PopnClassDetailView: View {
    let model: PopnAnalyticsModel

    var body: some View {
        PopnDetailList(isEmpty: model.popnClassCharts.isEmpty) {
            Section {
                ForEach(Array(model.popnClassCharts.enumerated()), id: \.offset) { index, record in
                    PopnEntryRow(title: record.title, difficulty: record.difficultyEnum, level: record.level) {
                        HStack(spacing: 6.0) {
                            Text(verbatim: "#\(index + 1)")
                                .foregroundStyle(.secondary)
                            Text(verbatim: String(format: "%.2f", record.popnClassPoint))
                                .fontWeight(.bold)
                            Text(record.score.formatted(.number))
                                .foregroundStyle(.secondary)
                            Text(verbatim: record.medalEnum.abbreviation)
                                .foregroundStyle(record.clearType.color)
                                .fontWeight(.bold)
                        }
                        .font(.caption)
                        .monospacedDigit()
                    }
                }
            } header: {
                HStack {
                    Text(verbatim: model.popnClassTier.name)
                        .foregroundStyle(model.popnClassTier.color)
                    Spacer()
                    Text(verbatim: model.popnClassText)
                        .monospacedDigit()
                }
                .font(.headline)
            }
        }
    }
}

struct PopnLevelBreakdownDetailView: View {
    let countsPerLevel: [Int: OrderedDictionary<String, Int>]
    let keys: [String]
    let color: (String) -> Color
    let label: (String) -> String

    var populatedLevels: [Int] {
        countsPerLevel.filter { _, counts in
            counts.values.contains(where: { $0 > 0 })
        }.keys.sorted()
    }

    var body: some View {
        PopnDetailList(isEmpty: populatedLevels.isEmpty) {
            Section {
                ForEach(populatedLevels, id: \.self) { level in
                    levelRow(level: level, counts: countsPerLevel[level] ?? [:])
                        .listRowBackground(Color.clear)
                }
            } header: {
                Text("Shared.Level")
            }
        }
    }

    @ViewBuilder
    func levelRow(level: Int, counts: OrderedDictionary<String, Int>) -> some View {
        let total = counts.values.reduce(0, +)
        let segments = keys.compactMap { key -> (key: String, count: Int)? in
            let count = counts[key] ?? 0
            return count > 0 ? (key, count) : nil
        }
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
                    ForEach(segments, id: \.key) { segment in
                        color(segment.key)
                            .frame(width: geometry.size.width * CGFloat(segment.count) / CGFloat(max(total, 1)))
                    }
                }
                .clipShape(.rect(cornerRadius: 4.0))
            }
            .frame(height: 16.0)
            HStack(spacing: 8.0) {
                ForEach(segments, id: \.key) { segment in
                    Text(verbatim: "\(label(segment.key)) \(segment.count)")
                        .foregroundStyle(color(segment.key))
                }
            }
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
        }
        .padding(.vertical, 4.0)
    }
}

// MARK: - Last Play detail views

struct PopnNewClearsDetailView: View {
    let newClears: [PopnNewClearEntry]

    var body: some View {
        PopnDetailList(isEmpty: newClears.isEmpty) {
            ForEach(newClears) { entry in
                PopnEntryRow(title: entry.songTitle, difficulty: entry.difficulty, level: entry.level) {
                    HStack(spacing: 4.0) {
                        let previous = PopnMedal(code: entry.previousMedal)
                        Text(verbatim: previous.abbreviation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .strikethrough()
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        let medal = PopnMedal(code: entry.medal)
                        Text(verbatim: medal.abbreviation)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(medal.clearType.color)
                    }
                }
            }
        }
    }
}

struct PopnNewRanksDetailView: View {
    let newRanks: [PopnNewRankEntry]

    var body: some View {
        PopnDetailList(isEmpty: newRanks.isEmpty) {
            ForEach(newRanks) { entry in
                PopnEntryRow(title: entry.songTitle, difficulty: entry.difficulty, level: entry.level) {
                    HStack(spacing: 4.0) {
                        PopnRankText(rank: entry.previousRank, strikethrough: true)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        PopnRankText(rank: entry.rank)
                    }
                    .fontWeight(.black)
                }
            }
        }
    }
}

struct PopnNewHighScoresDetailView: View {
    let newHighScores: [PopnNewHighScoreEntry]

    var body: some View {
        PopnDetailList(isEmpty: newHighScores.isEmpty) {
            ForEach(newHighScores) { entry in
                PopnEntryRow(title: entry.songTitle, difficulty: entry.difficulty, level: entry.level) {
                    HStack(spacing: 4.0) {
                        Text("\(entry.previousScore)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .strikethrough()
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(entry.newScore)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    if entry.newRank != entry.previousRank {
                        HStack(spacing: 4.0) {
                            PopnRankText(rank: entry.previousRank, strikethrough: true)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            PopnRankText(rank: entry.newRank)
                        }
                        .fontWeight(.black)
                    }
                }
            }
        }
    }
}
