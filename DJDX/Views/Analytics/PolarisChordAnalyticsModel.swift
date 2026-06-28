import OrderedCollections
import SwiftUI

@MainActor
@Observable
final class PolarisChordAnalyticsModel {

    // Clear-type counts per difficulty category (EASY/NORMAL/HARD/INFLUENCE/POLAR)
    var clearTypePerDifficulty: [PolarisChordDifficulty: OrderedDictionary<String, Int>] = [:]
    // Grade counts per difficulty category
    var gradePerDifficulty: [PolarisChordDifficulty: OrderedDictionary<String, Int>] = [:]
    // Counts per integer level
    var clearTypePerLevel: [Int: OrderedDictionary<String, Int>] = [:]

    var totalCharts: Int = 0

    // "前回のプレー" (Last Play): improvements between the latest two import groups.
    var newHighScores: [PolarisChordNewHighScoreEntry] = []
    var newClears: [String: [PolarisChordNewClearEntry]] = [:]   // key = PolarisChordClearType.rawValue
    var newGrades: [String: [PolarisChordNewGradeEntry]] = [:]   // key = PolarisChordGrade.rawValue

    // Clear types surfaced as "new clear" cards (worst-to-best, mirroring SDVX).
    nonisolated static let trackedClearTypes: [String] = [
        PolarisChordClearType.success.rawValue,
        PolarisChordClearType.fullCombo.rawValue,
        PolarisChordClearType.allPerfect.rawValue
    ]
    // Top grades surfaced as "new grade" cards (SSS+ down to S).
    nonisolated static let trackedGrades: [String] = [
        PolarisChordGrade.sssPlus.rawValue,
        PolarisChordGrade.sss.rawValue,
        PolarisChordGrade.ss.rawValue,
        PolarisChordGrade.s.rawValue
    ]

    var dataState: DataState = .initializing

    let fetcher = PolarisChordReader()

    func reload(version: PolarisChordVersion) async {
        dataState = .loading
        let records = await fetcher.latestSongRecords(for: version)

        var clearByDiff: [PolarisChordDifficulty: OrderedDictionary<String, Int>] = [:]
        var gradeByDiff: [PolarisChordDifficulty: OrderedDictionary<String, Int>] = [:]
        var clearByLevel: [Int: OrderedDictionary<String, Int>] = [:]

        let clearKeys = PolarisChordClearType.sortedStringsWithoutNoPlay
        let gradeKeys = PolarisChordGrade.sortedStrings

        func emptyClearCounts() -> OrderedDictionary<String, Int> {
            OrderedDictionary(uniqueKeys: clearKeys, values: clearKeys.map { _ in 0 })
        }
        func emptyGradeCounts() -> OrderedDictionary<String, Int> {
            OrderedDictionary(uniqueKeys: gradeKeys, values: gradeKeys.map { _ in 0 })
        }

        for record in records {
            let difficulty = record.difficultyEnum

            if clearByDiff[difficulty] == nil { clearByDiff[difficulty] = emptyClearCounts() }
            if gradeByDiff[difficulty] == nil { gradeByDiff[difficulty] = emptyGradeCounts() }

            if clearKeys.contains(record.clearType) {
                clearByDiff[difficulty]?[record.clearType]? += 1
            }
            if gradeKeys.contains(record.grade) {
                gradeByDiff[difficulty]?[record.grade]? += 1
            }

            let levelInt = Int(Double(record.level) ?? 0.0)
            if levelInt > 0 {
                if clearByLevel[levelInt] == nil { clearByLevel[levelInt] = emptyClearCounts() }
                if clearKeys.contains(record.clearType) {
                    clearByLevel[levelInt]?[record.clearType]? += 1
                }
            }
        }

        let lastPlay = await computeLastPlay(version: version)

        withAnimation(.smooth.speed(2.0)) {
            self.clearTypePerDifficulty = clearByDiff
            self.gradePerDifficulty = gradeByDiff
            self.clearTypePerLevel = clearByLevel
            self.totalCharts = records.count
            self.newClears = lastPlay.clears
            self.newHighScores = lastPlay.highScores
            self.newGrades = lastPlay.grades
            self.dataState = .presenting
        }
    }

    // Compares the latest two import groups for the version and computes what improved.
    // swiftlint:disable:next large_tuple
    private func computeLastPlay(version: PolarisChordVersion) async -> (
        clears: [String: [PolarisChordNewClearEntry]],
        highScores: [PolarisChordNewHighScoreEntry],
        grades: [String: [PolarisChordNewGradeEntry]]
    ) {
        let groups = await fetcher.importGroups(for: version)
        guard groups.count >= 2 else {
            return ([:], [], [:])
        }
        // importGroups is newest-first, so [0] is the latest and [1] the previous.
        let latestRecords = await fetcher.songRecords(for: groups[0].id)
        let previousRecords = await fetcher.songRecords(for: groups[1].id)
        return Self.computeNewEntries(latestRecords: latestRecords, previousRecords: previousRecords)
    }

    nonisolated static func computeNewEntries(
        latestRecords: [PolarisChordSongRecord],
        previousRecords: [PolarisChordSongRecord]
    // swiftlint:disable:next large_tuple
    ) -> (
        clears: [String: [PolarisChordNewClearEntry]],
        highScores: [PolarisChordNewHighScoreEntry],
        grades: [String: [PolarisChordNewGradeEntry]]
    ) {
        func key(_ record: PolarisChordSongRecord) -> String {
            "\(record.titleCompact())|\(record.difficulty)"
        }

        var previousByKey: [String: PolarisChordSongRecord] = [:]
        previousByKey.reserveCapacity(previousRecords.count)
        for record in previousRecords {
            previousByKey[key(record)] = record
        }

        var clears: [String: [PolarisChordNewClearEntry]] =
            Dictionary(uniqueKeysWithValues: trackedClearTypes.map { ($0, []) })
        var grades: [String: [PolarisChordNewGradeEntry]] =
            Dictionary(uniqueKeysWithValues: trackedGrades.map { ($0, []) })
        var highScores: [PolarisChordNewHighScoreEntry] = []

        for record in latestRecords {
            let previous = previousByKey[key(record)]
            let previousClearType = previous?.clearType ?? PolarisChordClearType.noPlay.rawValue
            let previousGrade = previous?.grade ?? PolarisChordGrade.none.rawValue
            let previousScore = previous?.score ?? 0

            if trackedClearTypes.contains(record.clearType), record.clearType != previousClearType {
                clears[record.clearType]?.append(PolarisChordNewClearEntry(
                    songTitle: record.title,
                    level: record.level,
                    difficulty: record.difficultyEnum,
                    clearType: record.clearType,
                    previousClearType: previousClearType
                ))
            }

            if trackedGrades.contains(record.grade), record.grade != previousGrade {
                grades[record.grade]?.append(PolarisChordNewGradeEntry(
                    songTitle: record.title,
                    level: record.level,
                    difficulty: record.difficultyEnum,
                    grade: record.grade,
                    previousGrade: previousGrade
                ))
            }

            if record.score > previousScore {
                highScores.append(PolarisChordNewHighScoreEntry(
                    songTitle: record.title,
                    level: record.level,
                    difficulty: record.difficultyEnum,
                    newScore: record.score,
                    previousScore: previousScore,
                    newGrade: record.grade,
                    previousGrade: previousGrade
                ))
            }
        }

        return (clears, highScores, grades)
    }
}
