import SwiftUI

struct TierListChart: Identifiable, Hashable {
    let id: String
    let title: String
    let level: String
    let difficultyLabel: String
    let difficultyColor: Color
    let lampLabel: String
    let lampColor: Color
    let grade: String
    let gradeColor: Color

    static func chartID(title: String, difficulty: String) -> String {
        "\(title)|\(difficulty)"
    }
}

enum TierListPlayType: String, CaseIterable, Identifiable {
    case single = "SP"
    case double = "DP"

    var id: String { rawValue }
}

extension Game {
    var tierListCode: String {
        switch self {
        case .iidxArcade: "iidx"
        case .iidxInfinitas: "infinitas"
        case .soundVoltex: "sdvx"
        case .polarisChord: "polarischord"
        case .danceDanceRevolution: "ddr"
        }
    }

    init?(tierListCode: String) {
        guard let game = Game.allCases.first(where: { $0.tierListCode == tierListCode }) else { return nil }
        self = game
    }

    var supportsTierListPlayType: Bool {
        isIIDXFamily || self == .danceDanceRevolution
    }
}

enum TierListChartProvider {

    static func levelSortKey(_ level: String) -> (Int, String) {
        (Int(level.prefix { $0.isNumber }) ?? 0, level)
    }

    static func sortedLevels(in charts: [TierListChart]) -> [String] {
        Set(charts.map(\.level)).sorted { levelSortKey($0) < levelSortKey($1) }
    }

    // swiftlint:disable:next function_parameter_count
    static func charts(
        for game: Game,
        playType: TierListPlayType,
        iidxVersion: IIDXVersion,
        sdvxVersion: SDVXVersion,
        polarisChordVersion: PolarisChordVersion,
        ddrVersion: DDRVersion
    ) async -> [TierListChart] {
        switch game {
        case .iidxArcade, .iidxInfinitas:
            await iidxCharts(playType: playType, version: iidxVersion)
        case .soundVoltex:
            await sdvxCharts(version: sdvxVersion)
        case .polarisChord:
            await polarisChordCharts(version: polarisChordVersion)
        case .danceDanceRevolution:
            await ddrCharts(playType: playType, version: ddrVersion)
        }
    }

    static func iidxCharts(playType: TierListPlayType, version: IIDXVersion) async -> [TierListChart] {
        let reader = IIDXReader()
        guard let importGroup = await reader.importGroup(for: .now, version: version) else { return [] }
        let records = await reader.songRecords(
            for: importGroup.id, playType: playType == .double ? .double : .single
        )
        let levels: [(IIDXLevel, String)] = [
            (.beginner, "BEGINNER"),
            (.normal, "NORMAL"),
            (.hyper, "HYPER"),
            (.another, "ANOTHER"),
            (.leggendaria, "LEGGENDARIA")
        ]
        return records.flatMap { record in
            levels.compactMap { level, name -> TierListChart? in
                guard let score = record.score(for: level), score.difficulty > 0 else { return nil }
                let djLevel = score.djLevel == "---" ? "" : score.djLevel
                return TierListChart(
                    id: TierListChart.chartID(title: record.title, difficulty: name),
                    title: record.title,
                    level: String(score.difficulty),
                    difficultyLabel: String(name.prefix(1)),
                    difficultyColor: iidxColor(for: level),
                    lampLabel: IIDXClearType.abbreviation(for: score.clearType),
                    lampColor: IIDXClearType.color(for: score.clearType),
                    grade: djLevel,
                    gradeColor: IIDXDJLevel.color(for: djLevel)
                )
            }
        }
    }

    static func iidxColor(for level: IIDXLevel) -> Color {
        switch level {
        case .beginner: .green
        case .normal: .blue
        case .hyper: .orange
        case .another: .red
        case .leggendaria: .purple
        default: .primary
        }
    }

    static func sdvxCharts(version: SDVXVersion) async -> [TierListChart] {
        await SDVXReader().latestSongRecords(for: version).compactMap { record in
            guard !record.level.isEmpty else { return nil }
            let difficulty = record.difficultyEnum
            let clearType = record.clearTypeEnum
            let grade = record.gradeEnum == .none ? "" : record.grade
            return TierListChart(
                id: TierListChart.chartID(title: record.title, difficulty: record.difficulty),
                title: record.title,
                level: record.level,
                difficultyLabel: difficulty.abbreviation,
                difficultyColor: difficulty.color,
                lampLabel: clearType.abbreviation,
                lampColor: clearType.color,
                grade: grade,
                gradeColor: SDVXGrade.color(for: grade)
            )
        }
    }

    static func polarisChordCharts(version: PolarisChordVersion) async -> [TierListChart] {
        await PolarisChordReader().latestSongRecords(for: version).compactMap { record in
            guard !record.level.isEmpty else { return nil }
            let difficulty = record.difficultyEnum
            let clearType = record.clearTypeEnum
            let grade = record.gradeEnum == .none ? "" : record.grade
            return TierListChart(
                id: TierListChart.chartID(title: record.title, difficulty: record.difficulty),
                title: record.title,
                level: record.level,
                difficultyLabel: difficulty.abbreviation,
                difficultyColor: difficulty.color,
                lampLabel: clearType.abbreviation,
                lampColor: clearType.color,
                grade: grade,
                gradeColor: .secondary
            )
        }
    }

    static func ddrCharts(playType: TierListPlayType, version: DDRVersion) async -> [TierListChart] {
        let style: DDRPlayStyle = playType == .double ? .double : .single
        return await DDRReader().latestSongRecords(for: version).compactMap { record in
            guard record.styleEnum == style, record.level > 0 else { return nil }
            let difficulty = record.difficultyEnum
            return TierListChart(
                id: TierListChart.chartID(title: record.title, difficulty: record.difficulty),
                title: record.title,
                level: String(record.level),
                difficultyLabel: String(record.difficulty.prefix(3)),
                difficultyColor: difficulty.color,
                lampLabel: record.clearDisplay,
                lampColor: DDRSongRecord.clearColor(for: record.clearKind),
                grade: record.rankDisplay,
                gradeColor: DDRSongRecord.rankColor(forStem: record.rank)
            )
        }
    }
}
