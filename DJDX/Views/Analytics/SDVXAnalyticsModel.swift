import OrderedCollections
import SwiftUI

@MainActor
@Observable
final class SDVXAnalyticsModel {

    // Clear-type counts per difficulty category (NOV/ADV/EXH/MXM/INF-tier)
    var clearTypePerDifficulty: [SDVXDifficulty: OrderedDictionary<String, Int>] = [:]
    // Grade counts per difficulty category
    var gradePerDifficulty: [SDVXDifficulty: OrderedDictionary<String, Int>] = [:]
    // Counts per integer level (4...20)
    var clearTypePerLevel: [Int: OrderedDictionary<String, Int>] = [:]

    var totalCharts: Int = 0
    var totalPlays: Int = 0
    var volforce: Double = 0.0

    // "前回のプレー" (Last Play): improvements between the latest two import groups.
    var newHighScores: [SDVXNewHighScoreEntry] = []
    var newClears: [String: [SDVXNewClearEntry]] = [:]   // key = SDVXClearType.rawValue
    var newGrades: [String: [SDVXNewGradeEntry]] = [:]   // key = SDVXGrade.rawValue

    // Clear ranks surfaced as "new clear" cards (mirrors IIDX's per-type cards, minus PLAYED).
    nonisolated static let trackedClearTypes: [String] = [
        SDVXClearType.complete.rawValue,
        SDVXClearType.excessive.rawValue,
        SDVXClearType.ultimateChain.rawValue,
        SDVXClearType.perfectUltimateChain.rawValue
    ]
    // Grades surfaced as "new grade" cards, offered down to A (the view defaults
    // to showing only the top grades, down to AAA).
    nonisolated static let trackedGrades: [String] = [
        SDVXGrade.s.rawValue,
        SDVXGrade.aaaPlus.rawValue,
        SDVXGrade.aaa.rawValue,
        SDVXGrade.aaPlus.rawValue,
        SDVXGrade.aa.rawValue,
        SDVXGrade.aPlus.rawValue,
        SDVXGrade.a.rawValue
    ]

    var dataState: DataState = .initializing

    let fetcher = SDVXReader()

    // VOLFORCE per chart: floor(level * grade_coef * clear_coef * 2) / 100, summed over best 50.
    // Score-based single-chart force ~= level * 2 * (score / 10_000_000) as an approximation.
    private func chartForce(_ record: SDVXSongRecord) -> Double {
        let levelValue = Double(record.level) ?? 0.0
        guard levelValue > 0, record.highScore > 0 else { return 0.0 }
        return levelValue * 2.0 * (Double(record.highScore) / 10_000_000.0)
    }

    func reload(version: SDVXVersion) async {
        dataState = .loading
        let records = await fetcher.latestSongRecords(for: version)

        var clearByDiff: [SDVXDifficulty: OrderedDictionary<String, Int>] = [:]
        var gradeByDiff: [SDVXDifficulty: OrderedDictionary<String, Int>] = [:]
        var clearByLevel: [Int: OrderedDictionary<String, Int>] = [:]
        var plays = 0

        let clearKeys = SDVXClearType.sortedStringsWithoutNoPlay
        let gradeKeys = SDVXGrade.sortedStrings

        func emptyClearCounts() -> OrderedDictionary<String, Int> {
            OrderedDictionary(uniqueKeys: clearKeys, values: clearKeys.map { _ in 0 })
        }
        func emptyGradeCounts() -> OrderedDictionary<String, Int> {
            OrderedDictionary(uniqueKeys: gradeKeys, values: gradeKeys.map { _ in 0 })
        }

        for record in records {
            plays += record.playCount
            let difficulty = record.difficultyEnum
            // Group all infinite-tier charts under .infinite for the per-category view
            let category: SDVXDifficulty = difficulty.isInfiniteTier ? .infinite : difficulty

            if clearByDiff[category] == nil { clearByDiff[category] = emptyClearCounts() }
            if gradeByDiff[category] == nil { gradeByDiff[category] = emptyGradeCounts() }

            if clearKeys.contains(record.clearType) {
                clearByDiff[category]?[record.clearType]? += 1
            }
            if gradeKeys.contains(record.grade) {
                gradeByDiff[category]?[record.grade]? += 1
            }

            let levelInt = Int(Double(record.level) ?? 0.0)
            if levelInt > 0 {
                if clearByLevel[levelInt] == nil { clearByLevel[levelInt] = emptyClearCounts() }
                if clearKeys.contains(record.clearType) {
                    clearByLevel[levelInt]?[record.clearType]? += 1
                }
            }
        }

        let topForces = records.map { chartForce($0) }.sorted(by: >).prefix(50)
        let computedVolforce = (topForces.reduce(0.0, +) * 100).rounded() / 100

        let lastPlay = await computeLastPlay(version: version)

        withAnimation(.smooth.speed(2.0)) {
            self.clearTypePerDifficulty = clearByDiff
            self.gradePerDifficulty = gradeByDiff
            self.clearTypePerLevel = clearByLevel
            self.totalCharts = records.count
            self.totalPlays = plays
            self.volforce = computedVolforce
            self.newClears = lastPlay.clears
            self.newHighScores = lastPlay.highScores
            self.newGrades = lastPlay.grades
            self.dataState = .presenting
        }
    }

    // Compares the latest two import groups for the version and computes what improved.
    private func computeLastPlay(version: SDVXVersion) async -> (
        clears: [String: [SDVXNewClearEntry]],
        highScores: [SDVXNewHighScoreEntry],
        grades: [String: [SDVXNewGradeEntry]]
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
        latestRecords: [SDVXSongRecord],
        previousRecords: [SDVXSongRecord]
    ) -> (
        clears: [String: [SDVXNewClearEntry]],
        highScores: [SDVXNewHighScoreEntry],
        grades: [String: [SDVXNewGradeEntry]]
    ) {
        func key(_ record: SDVXSongRecord) -> String {
            "\(record.titleCompact())|\(record.difficulty)"
        }

        var previousByKey: [String: SDVXSongRecord] = [:]
        previousByKey.reserveCapacity(previousRecords.count)
        for record in previousRecords {
            previousByKey[key(record)] = record
        }

        var clears: [String: [SDVXNewClearEntry]] =
            Dictionary(uniqueKeysWithValues: trackedClearTypes.map { ($0, []) })
        var grades: [String: [SDVXNewGradeEntry]] =
            Dictionary(uniqueKeysWithValues: trackedGrades.map { ($0, []) })
        var highScores: [SDVXNewHighScoreEntry] = []

        for record in latestRecords {
            let previous = previousByKey[key(record)]
            let previousClearType = previous?.clearType ?? SDVXClearType.noPlay.rawValue
            let previousGrade = previous?.grade ?? SDVXGrade.none.rawValue
            let previousScore = previous?.highScore ?? 0

            if trackedClearTypes.contains(record.clearType), record.clearType != previousClearType {
                clears[record.clearType]?.append(SDVXNewClearEntry(
                    songTitle: record.title,
                    level: record.level,
                    difficulty: record.difficultyEnum,
                    clearType: record.clearType,
                    previousClearType: previousClearType
                ))
            }

            if trackedGrades.contains(record.grade), record.grade != previousGrade {
                grades[record.grade]?.append(SDVXNewGradeEntry(
                    songTitle: record.title,
                    level: record.level,
                    difficulty: record.difficultyEnum,
                    grade: record.grade,
                    previousGrade: previousGrade
                ))
            }

            if record.highScore > previousScore {
                highScores.append(SDVXNewHighScoreEntry(
                    songTitle: record.title,
                    level: record.level,
                    difficulty: record.difficultyEnum,
                    newScore: record.highScore,
                    previousScore: previousScore,
                    newGrade: record.grade,
                    previousGrade: previousGrade
                ))
            }
        }

        return (clears, highScores, grades)
    }
}
