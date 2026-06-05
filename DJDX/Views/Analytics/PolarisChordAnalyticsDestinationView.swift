import SwiftUI

struct PolarisChordAnalyticsDestinationView: View {

    @Bindable var model: PolarisChordAnalyticsModel
    let path: PolarisChordAnalyticsPath
    var namespace: Namespace.ID

    var body: some View {
        Group {
            switch path {
            case .newHighScoresDetail:
                PolarisChordNewHighScoresDetailView(newHighScores: model.newHighScores)
                    .navigationTitle("Analytics.NewHighScores")
                    .automaticNavigationTransition(id: "PolarisChord.newHighScores", in: namespace)
            case .newClearsDetail(let clearType):
                PolarisChordNewClearsDetailView(newClears: model.newClears[clearType] ?? [])
                    .navigationTitle(Text(verbatim: clearType))
                    .automaticNavigationTransition(
                        id: transitionID(forClearType: clearType), in: namespace
                    )
            case .newGradesDetail(let grade):
                PolarisChordNewGradesDetailView(newGrades: model.newGrades[grade] ?? [])
                    .navigationTitle(Text(verbatim: grade))
                    .automaticNavigationTransition(id: transitionID(forGrade: grade), in: namespace)
            }
        }
        .appBackgroundGradient()
        .navigationBarTitleDisplayMode(.inline)
    }

    func transitionID(forClearType clearType: String) -> String {
        switch PolarisChordClearType(rawValue: clearType) {
        case .success: return "PolarisChord.newClearSuccess"
        case .fullCombo: return "PolarisChord.newClearFullCombo"
        case .allPerfect: return "PolarisChord.newClearAllPerfect"
        default: return "PolarisChord.newClears"
        }
    }

    func transitionID(forGrade grade: String) -> String {
        switch PolarisChordGrade(rawValue: grade) {
        case .sssPlus: return "PolarisChord.newGradeSSSPlus"
        case .sss: return "PolarisChord.newGradeSSS"
        case .ss: return "PolarisChord.newGradeSS"
        case .s: return "PolarisChord.newGradeS"
        default: return "PolarisChord.newGrades"
        }
    }
}

// MARK: - Shared label

// Difficulty + level chip, matching the SDVX last-play detail label.
struct PolarisChordLevelLabel: View {
    let difficulty: PolarisChordDifficulty
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

// Styled grade text using the grade's own shape style.
private struct PolarisChordGradeText: View {
    @Environment(\.colorScheme) private var colorScheme
    let grade: String
    var strikethrough: Bool = false

    var body: some View {
        let gradeEnum = PolarisChordGrade(rawValue: grade) ?? .unknown
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

// MARK: - Last Play detail views

struct PolarisChordNewClearsDetailView: View {
    let newClears: [PolarisChordNewClearEntry]

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
                                Text(verbatim: PolarisChordClearType(rawValue: entry.previousClearType)?.abbreviation
                                     ?? entry.previousClearType)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .strikethrough()
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                let clear = PolarisChordClearType(rawValue: entry.clearType)
                                Text(verbatim: clear?.abbreviation ?? entry.clearType)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(clear?.color ?? .primary)
                            }
                        }
                        Spacer(minLength: 0.0)
                        PolarisChordLevelLabel(difficulty: entry.difficulty, level: entry.level)
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

struct PolarisChordNewGradesDetailView: View {
    let newGrades: [PolarisChordNewGradeEntry]

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
                                PolarisChordGradeText(grade: entry.previousGrade, strikethrough: true)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                PolarisChordGradeText(grade: entry.grade)
                            }
                            .fontWeight(.black)
                        }
                        Spacer(minLength: 0.0)
                        PolarisChordLevelLabel(difficulty: entry.difficulty, level: entry.level)
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

struct PolarisChordNewHighScoresDetailView: View {
    let newHighScores: [PolarisChordNewHighScoreEntry]

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
                                    .foregroundStyle(.primary)
                            }
                            if entry.newGrade != entry.previousGrade {
                                HStack(spacing: 4.0) {
                                    PolarisChordGradeText(grade: entry.previousGrade, strikethrough: true)
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    PolarisChordGradeText(grade: entry.newGrade)
                                }
                                .fontWeight(.black)
                            }
                        }
                        Spacer(minLength: 0.0)
                        PolarisChordLevelLabel(difficulty: entry.difficulty, level: entry.level)
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
