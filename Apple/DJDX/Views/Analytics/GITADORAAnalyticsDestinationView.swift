import Charts
import OrderedCollections
import SwiftUI

struct GITADORAAnalyticsDestinationView: View {

    @Bindable var model: GITADORAAnalyticsModel
    let path: GITADORAAnalyticsPath
    var namespace: Namespace.ID

    var body: some View {
        Group {
            switch path {
            case .skillDetail:
                GITADORASkillDetailView(records: model.topSkillRecords)
                    .navigationTitle("Shared.GITADORA.Skill")
                    .navigationTransition(.zoom(sourceID: "GITADORA.skill", in: namespace))
            case .clearBreakdownDetail:
                GITADORALevelBreakdownDetailView(countsPerLevel: model.clearTypePerLevel,
                                                 keys: GITADORAClearType.sortedStringsWithoutNoPlay,
                                                 style: {
                                                     AnyShapeStyle(GITADORAClearType(rawValue: $0)?.color ?? .gray)
                                                 })
                    .navigationTitle("Analytics.GITADORA.ClearBreakdown")
                    .navigationTransition(.zoom(sourceID: "GITADORA.clearBreakdown", in: namespace))
            case .rankBreakdownDetail:
                GITADORALevelBreakdownDetailView(countsPerLevel: model.rankPerLevel,
                                                 keys: GITADORARank.sortedStrings,
                                                 style: { AnyShapeStyle(GITADORARank.color(for: $0)) })
                    .navigationTitle("Analytics.GITADORA.RankBreakdown")
                    .navigationTransition(.zoom(sourceID: "GITADORA.rankBreakdown", in: namespace))
            case .newHighScoresDetail:
                GITADORANewHighScoresDetailView(newHighScores: model.newHighScores)
                    .navigationTitle("Analytics.NewHighScores")
                    .navigationTransition(.zoom(sourceID: "GITADORA.newHighScores", in: namespace))
            case .newClearsDetail(let clearType):
                GITADORANewClearsDetailView(newClears: model.newClears[clearType] ?? [])
                    .navigationTitle(Text(verbatim: clearType))
                    .navigationTransition(.zoom(sourceID: transitionID(forClearType: clearType), in: namespace))
            case .newRanksDetail(let rank):
                GITADORANewRanksDetailView(newRanks: model.newRanks[rank] ?? [])
                    .navigationTitle(Text(verbatim: rank))
                    .navigationTransition(.zoom(sourceID: transitionID(forRank: rank), in: namespace))
            }
        }
        .appBackgroundGradient()
        .navigationBarTitleDisplayMode(.inline)
    }

    func transitionID(forClearType clearType: String) -> String {
        switch GITADORAClearType(rawValue: clearType) {
        case .clear: return "GITADORA.newClearClear"
        case .fullCombo: return "GITADORA.newClearFullCombo"
        case .excellent: return "GITADORA.newClearExcellent"
        default: return "GITADORA.newClears"
        }
    }

    func transitionID(forRank rank: String) -> String {
        switch GITADORARank(rawValue: rank) {
        case .ss: return "GITADORA.newRankSS"
        case .s: return "GITADORA.newRankS"
        default: return "GITADORA.newRanks"
        }
    }
}

// MARK: - Shared label

struct GITADORALevelLabel: View {
    let difficulty: GITADORADifficulty
    let level: String

    var body: some View {
        VStack(spacing: 1.0) {
            Text(verbatim: difficulty.abbreviation)
                .font(.system(size: 10.0).weight(.black))
                .foregroundStyle(difficulty.color)
            Text(verbatim: level)
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

private struct GITADORARankText: View {
    @Environment(\.colorScheme) private var colorScheme
    let grade: String
    var strikethrough: Bool = false

    var body: some View {
        let gradeEnum = GITADORARank(rawValue: grade) ?? .unknown
        Group {
            if strikethrough {
                Text(verbatim: grade)
                    .strikethrough()
                    .foregroundStyle(.secondary)
            } else {
                Text(verbatim: grade)
                    .foregroundStyle(AnyShapeStyle(gradeEnum.style(colorScheme: colorScheme)))
            }
        }
        .font(.caption.weight(.semibold))
        .fontWidth(.expanded)
    }
}

// MARK: - Overview expansion detail views

struct GITADORASkillDetailView: View {
    let records: [GITADORASongRecord]

    var body: some View {
        List {
            if records.isEmpty {
                Text("Analytics.NoData")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(Array(records.enumerated()), id: \.offset) { index, record in
                    HStack(alignment: .center, spacing: 8.0) {
                        Text(verbatim: "\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 24.0)
                        VStack(alignment: .leading, spacing: 2.0) {
                            Text(record.title)
                                .bold()
                                .fontWidth(.condensed)
                            HStack(spacing: 6.0) {
                                Text(verbatim: String(format: "%.2f", record.skillValue))
                                    .fontWeight(.semibold)
                                Text(verbatim: "\(record.achievementRate)%")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                            .monospacedDigit()
                        }
                        Spacer(minLength: 0.0)
                        GITADORALevelLabel(difficulty: record.difficultyEnum, level: record.level)
                    }
                    .padding(.vertical, 2.0)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

struct GITADORALevelBreakdownDetailView: View {
    let countsPerLevel: [Int: OrderedDictionary<String, Int>]
    let keys: [String]
    let style: (String) -> AnyShapeStyle

    var populatedLevels: [Int] {
        countsPerLevel.filter { _, counts in
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
                        GITADORALevelRow(counts: countsPerLevel[level] ?? [:], keys: keys, style: style, level: level)
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

struct GITADORALevelRow: View {
    let counts: OrderedDictionary<String, Int>
    let keys: [String]
    let style: (String) -> AnyShapeStyle
    let level: Int

    var total: Int { counts.values.reduce(0, +) }

    var segments: [(type: String, count: Int)] {
        keys.compactMap { type in
            let count = counts[type] ?? 0
            return count > 0 ? (type, count) : nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6.0) {
            HStack {
                LevelNumberBadge(level: String(level))
                Spacer()
                Text("Shared.SongCount.\(total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            GeometryReader { geometry in
                HStack(spacing: 0.0) {
                    ForEach(segments, id: \.type) { segment in
                        Rectangle()
                            .fill(style(segment.type))
                            .frame(width: geometry.size.width * CGFloat(segment.count) / CGFloat(max(total, 1)))
                    }
                }
                .clipShape(.rect(cornerRadius: 4.0))
            }
            .frame(height: 16.0)
            HStack(spacing: 8.0) {
                ForEach(segments, id: \.type) { segment in
                    Text(verbatim: "\(segment.type) \(segment.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 4.0)
    }
}

// MARK: - Last Play detail views

struct GITADORANewClearsDetailView: View {
    let newClears: [GITADORANewClearEntry]

    var body: some View {
        List {
            if newClears.isEmpty {
                Text("Analytics.NoData")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(newClears) { entry in
                    HStack(alignment: .center, spacing: 8.0) {
                        VStack(alignment: .leading, spacing: 2.0) {
                            Text(entry.songTitle)
                                .bold()
                                .fontWidth(.condensed)
                            HStack(spacing: 4.0) {
                                Text(verbatim: GITADORAClearType(rawValue: entry.previousClearType)?.abbreviation
                                     ?? entry.previousClearType)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .strikethrough()
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                let clear = GITADORAClearType(rawValue: entry.clearType)
                                Text(verbatim: clear?.abbreviation ?? entry.clearType)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(clear?.color ?? .primary)
                            }
                        }
                        Spacer(minLength: 0.0)
                        GITADORALevelLabel(difficulty: entry.difficulty, level: entry.level)
                    }
                    .padding(.vertical, 2.0)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

struct GITADORANewRanksDetailView: View {
    let newRanks: [GITADORANewRankEntry]

    var body: some View {
        List {
            if newRanks.isEmpty {
                Text("Analytics.NoData")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(newRanks) { entry in
                    HStack(alignment: .center, spacing: 8.0) {
                        VStack(alignment: .leading, spacing: 2.0) {
                            Text(entry.songTitle)
                                .bold()
                                .fontWidth(.condensed)
                            HStack(spacing: 4.0) {
                                GITADORARankText(grade: entry.previousRank, strikethrough: true)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                GITADORARankText(grade: entry.rank)
                            }
                            .fontWeight(.black)
                        }
                        Spacer(minLength: 0.0)
                        GITADORALevelLabel(difficulty: entry.difficulty, level: entry.level)
                    }
                    .padding(.vertical, 2.0)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

struct GITADORANewHighScoresDetailView: View {
    let newHighScores: [GITADORANewHighScoreEntry]

    var body: some View {
        List {
            if newHighScores.isEmpty {
                Text("Analytics.NoData")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(newHighScores) { entry in
                    HStack(alignment: .center, spacing: 8.0) {
                        VStack(alignment: .leading, spacing: 2.0) {
                            Text(entry.songTitle)
                                .bold()
                                .fontWidth(.condensed)
                            HStack(spacing: 4.0) {
                                Text(verbatim: entry.previousRate.isEmpty ? "-" : "\(entry.previousRate)%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .strikethrough()
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(verbatim: "\(entry.newRate)%")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                            if entry.newRank != entry.previousRank {
                                HStack(spacing: 4.0) {
                                    GITADORARankText(grade: entry.previousRank, strikethrough: true)
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    GITADORARankText(grade: entry.newRank)
                                }
                                .fontWeight(.black)
                            }
                        }
                        Spacer(minLength: 0.0)
                        GITADORALevelLabel(difficulty: entry.difficulty, level: entry.level)
                    }
                    .padding(.vertical, 2.0)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
