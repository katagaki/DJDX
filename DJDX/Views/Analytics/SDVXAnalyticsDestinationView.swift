import Charts
import OrderedCollections
import SwiftUI

struct SDVXAnalyticsDestinationView: View {

    @Bindable var model: SDVXAnalyticsModel
    let path: SDVXAnalyticsPath
    var namespace: Namespace.ID

    var body: some View {
        Group {
            switch path {
            case .clearBreakdownDetail:
                SDVXClearBreakdownDetailView(clearTypePerLevel: model.clearTypePerLevel)
                    .navigationTitle("Analytics.SDVX.ClearBreakdown")
                    .automaticNavigationTransition(id: "SDVX.clearBreakdown", in: namespace)
            case .gradeBreakdownDetail:
                SDVXGradeBreakdownDetailView(gradePerDifficulty: model.gradePerDifficulty)
                    .navigationTitle("Analytics.SDVX.GradeBreakdown")
                    .automaticNavigationTransition(id: "SDVX.gradeBreakdown", in: namespace)
            case .newHighScoresDetail:
                SDVXNewHighScoresDetailView(newHighScores: model.newHighScores)
                    .navigationTitle("Analytics.NewHighScores")
                    .automaticNavigationTransition(id: "SDVX.newHighScores", in: namespace)
            case .newClearsDetail(let clearType):
                SDVXNewClearsDetailView(newClears: model.newClears[clearType] ?? [])
                    .navigationTitle(Text(verbatim: clearType))
                    .automaticNavigationTransition(
                        id: transitionID(forClearType: clearType), in: namespace
                    )
            case .newGradesDetail(let grade):
                SDVXNewGradesDetailView(newGrades: model.newGrades[grade] ?? [])
                    .navigationTitle(Text(verbatim: grade))
                    .automaticNavigationTransition(id: transitionID(forGrade: grade), in: namespace)
            }
        }
        .appBackgroundGradient()
        .navigationBarTitleDisplayMode(.inline)
    }

    func transitionID(forClearType clearType: String) -> String {
        switch SDVXClearType(rawValue: clearType) {
        case .complete: return "SDVX.newClearComplete"
        case .excessive: return "SDVX.newClearExcessive"
        case .ultimateChain: return "SDVX.newClearUltimateChain"
        case .perfectUltimateChain: return "SDVX.newClearPerfectUC"
        default: return "SDVX.newClears"
        }
    }

    func transitionID(forGrade grade: String) -> String {
        switch SDVXGrade(rawValue: grade) {
        case .s: return "SDVX.newGradeS"
        case .aaaPlus: return "SDVX.newGradeAAAPlus"
        case .aaa: return "SDVX.newGradeAAA"
        case .aaPlus: return "SDVX.newGradeAAPlus"
        case .aa: return "SDVX.newGradeAA"
        case .aPlus: return "SDVX.newGradeAPlus"
        case .a: return "SDVX.newGradeA"
        default: return "SDVX.newGrades"
        }
    }
}

// MARK: - Shared label

// Difficulty + level chip, matching the trailing block in SDVXScoreRow.
struct SDVXLevelLabel: View {
    let difficulty: SDVXDifficulty
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

// MARK: - Last Play detail views

struct SDVXNewClearsDetailView: View {
    let newClears: [SDVXNewClearEntry]

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
                                Text(verbatim: SDVXClearType(rawValue: entry.previousClearType)?.abbreviation
                                     ?? entry.previousClearType)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .strikethrough()
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(verbatim: SDVXClearType(rawValue: entry.clearType)?.abbreviation
                                     ?? entry.clearType)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(SDVXClearType(rawValue: entry.clearType)?.color ?? .primary)
                            }
                        }
                        Spacer(minLength: 0.0)
                        SDVXLevelLabel(difficulty: entry.difficulty, level: entry.level)
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

struct SDVXNewGradesDetailView: View {
    let newGrades: [SDVXNewGradeEntry]

    var body: some View {
        List {
            if newGrades.isEmpty {
                Text("Analytics.NoData")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(newGrades) { entry in
                    HStack(alignment: .center, spacing: 8.0) {
                        VStack(alignment: .leading, spacing: 2.0) {
                            Text(entry.songTitle)
                                .bold()
                                .fontWidth(.condensed)
                            HStack(spacing: 4.0) {
                                Text(verbatim: entry.previousGrade)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fontWidth(.expanded)
                                    .strikethrough()
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(verbatim: entry.grade)
                                    .font(.caption.weight(.semibold))
                                    .fontWidth(.expanded)
                                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange],
                                                                    startPoint: .top, endPoint: .bottom))
                            }
                            .fontWeight(.black)
                        }
                        Spacer(minLength: 0.0)
                        SDVXLevelLabel(difficulty: entry.difficulty, level: entry.level)
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

struct SDVXNewHighScoresDetailView: View {
    let newHighScores: [SDVXNewHighScoreEntry]

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
                                Text("\(entry.previousScore)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .strikethrough()
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(entry.newScore)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                                Text("Analytics.NewHighScore.\(entry.newScore - entry.previousScore)")
                                    .font(.caption2)
                                    .foregroundStyle(.orange.opacity(0.8))
                            }
                            if entry.newGrade != entry.previousGrade {
                                HStack(spacing: 4.0) {
                                    Text(verbatim: entry.previousGrade)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fontWidth(.expanded)
                                        .strikethrough()
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(verbatim: entry.newGrade)
                                        .font(.caption.weight(.semibold))
                                        .fontWidth(.expanded)
                                        .foregroundStyle(LinearGradient(colors: [.yellow, .orange],
                                                                        startPoint: .top, endPoint: .bottom))
                                }
                                .fontWeight(.black)
                            }
                        }
                        Spacer(minLength: 0.0)
                        SDVXLevelLabel(difficulty: entry.difficulty, level: entry.level)
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

// MARK: - Overview expansion detail views

struct SDVXClearBreakdownDetailView: View {
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
                        SDVXClearTypeLevelRow(counts: clearTypePerLevel[level] ?? [:], level: level)
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

struct SDVXClearTypeLevelRow: View {
    let counts: OrderedDictionary<String, Int>
    let level: Int

    var total: Int { counts.values.reduce(0, +) }

    var segments: [(type: String, count: Int)] {
        SDVXClearType.sortedStringsWithoutNoPlay.compactMap { type in
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
                        (SDVXClearType(rawValue: segment.type)?.color ?? .gray)
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

struct SDVXGradeBreakdownDetailView: View {
    let gradePerDifficulty: [SDVXDifficulty: OrderedDictionary<String, Int>]

    var populatedDifficulties: [SDVXDifficulty] {
        SDVXDifficulty.sorted.filter { difficulty in
            (gradePerDifficulty[difficulty]?.values.contains(where: { $0 > 0 })) ?? false
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
                        Chart(gradeElements(for: difficulty), id: \.key) { element in
                            BarMark(
                                x: .value("Shared.SDVX.Grade", element.key),
                                y: .value("Shared.ClearCount", element.value)
                            )
                            .foregroundStyle(.orange)
                        }
                        .frame(height: 140.0)
                        .listRowBackground(Color.clear)
                    } header: {
                        Text(verbatim: difficulty.abbreviation)
                            .foregroundStyle(difficulty.color)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    func gradeElements(for difficulty: SDVXDifficulty) -> [(key: String, value: Int)] {
        let counts = gradePerDifficulty[difficulty] ?? [:]
        return SDVXGrade.sortedStrings.compactMap { grade in
            let count = counts[grade] ?? 0
            return count > 0 ? (grade, count) : nil
        }
    }
}
