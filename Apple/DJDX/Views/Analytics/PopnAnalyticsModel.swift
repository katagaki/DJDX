import OrderedCollections
import SwiftUI

@MainActor
@Observable
final class PopnAnalyticsModel {

    var clearTypeTotals: OrderedDictionary<String, Int> = [:]
    var rankTotals: OrderedDictionary<String, Int> = [:]
    var clearTypePerLevel: [Int: OrderedDictionary<String, Int>] = [:]
    var rankPerLevel: [Int: OrderedDictionary<String, Int>] = [:]

    var popnClassValue: Double = 0.0
    var officialPopnClass: String?
    var popnClassCharts: [PopnSongRecord] = []

    var newHighScores: [PopnNewHighScoreEntry] = []
    var newClears: [String: [PopnNewClearEntry]] = [:]
    var newRanks: [String: [PopnNewRankEntry]] = [:]

    nonisolated static let trackedClearTypes: [String] = [
        PopnClearType.clear.rawValue,
        PopnClearType.fullCombo.rawValue,
        PopnClearType.perfect.rawValue
    ]
    nonisolated static let trackedRanks: [String] = [
        PopnRank.s.rawValue,
        PopnRank.aaa.rawValue,
        PopnRank.aa.rawValue
    ]

    var dataState: DataState = .initializing

    let fetcher = PopnReader()

    var popnClassText: String {
        officialPopnClass ?? String(format: "%.2f", popnClassValue)
    }

    var popnClassTier: PopnClass.Tier {
        PopnClass.tier(for: Double(popnClassText) ?? popnClassValue)
    }

    func reload(version: PopnVersion, filters: PopnFilterOptions? = nil) async {
        dataState = .loading
        let allRecords = await fetcher.latestSongRecords(for: version)
        var records = allRecords
        if let filters {
            records = records.filter { filters.matches($0) }
        }

        let clearKeys = PopnClearType.sortedStringsWithoutNoPlay
        let rankKeys = PopnRank.sortedStrings

        var clearTotals = Self.emptyCounts(clearKeys)
        var rankTotals = Self.emptyCounts(rankKeys)
        var clearByLevel: [Int: OrderedDictionary<String, Int>] = [:]
        var rankByLevel: [Int: OrderedDictionary<String, Int>] = [:]

        for record in records {
            let clearType = record.clearType.rawValue
            let rank = record.rank
            if clearKeys.contains(clearType) {
                clearTotals[clearType]? += 1
            }
            if rankKeys.contains(rank) {
                rankTotals[rank]? += 1
            }
            guard record.level > 0 else { continue }
            if clearByLevel[record.level] == nil { clearByLevel[record.level] = Self.emptyCounts(clearKeys) }
            if rankByLevel[record.level] == nil { rankByLevel[record.level] = Self.emptyCounts(rankKeys) }
            if clearKeys.contains(clearType) {
                clearByLevel[record.level]?[clearType]? += 1
            }
            if rankKeys.contains(rank) {
                rankByLevel[record.level]?[rank]? += 1
            }
        }

        let classCharts = PopnClass.topCharts(allRecords)
        let classValue = PopnClass.value(for: allRecords)
        let official = PopnProfile.load(for: version).popnClass
        let lastPlay = await computeLastPlay(version: version, filters: filters)

        withAnimation(.smooth.speed(2.0)) {
            self.clearTypeTotals = clearTotals
            self.rankTotals = rankTotals
            self.clearTypePerLevel = clearByLevel
            self.rankPerLevel = rankByLevel
            self.popnClassCharts = classCharts
            self.popnClassValue = classValue
            self.officialPopnClass = official
            self.newClears = lastPlay.clears
            self.newHighScores = lastPlay.highScores
            self.newRanks = lastPlay.ranks
            self.dataState = .presenting
        }
    }

    nonisolated static func emptyCounts(_ keys: [String]) -> OrderedDictionary<String, Int> {
        OrderedDictionary(uniqueKeys: keys, values: keys.map { _ in 0 })
    }

    // swiftlint:disable:next large_tuple
    private func computeLastPlay(version: PopnVersion, filters: PopnFilterOptions?) async -> (
        clears: [String: [PopnNewClearEntry]],
        highScores: [PopnNewHighScoreEntry],
        ranks: [String: [PopnNewRankEntry]]
    ) {
        let groups = await fetcher.importGroups(for: version)
        guard groups.count >= 2 else { return ([:], [], [:]) }
        var latestRecords = await fetcher.songRecords(for: groups[0].id)
        if let filters {
            latestRecords = latestRecords.filter { filters.matches($0) }
        }
        let previousRecords = await fetcher.songRecords(for: groups[1].id)
        return Self.computeNewEntries(latestRecords: latestRecords, previousRecords: previousRecords)
    }

    nonisolated static func computeNewEntries(
        latestRecords: [PopnSongRecord],
        previousRecords: [PopnSongRecord]
    // swiftlint:disable:next large_tuple
    ) -> (
        clears: [String: [PopnNewClearEntry]],
        highScores: [PopnNewHighScoreEntry],
        ranks: [String: [PopnNewRankEntry]]
    ) {
        func key(_ record: PopnSongRecord) -> String {
            "\(record.titleCompact())|\(record.genre)|\(record.difficulty)"
        }

        var previousByKey: [String: PopnSongRecord] = [:]
        previousByKey.reserveCapacity(previousRecords.count)
        for record in previousRecords {
            previousByKey[key(record)] = record
        }

        var clears: [String: [PopnNewClearEntry]] =
            Dictionary(uniqueKeysWithValues: trackedClearTypes.map { ($0, []) })
        var ranks: [String: [PopnNewRankEntry]] =
            Dictionary(uniqueKeysWithValues: trackedRanks.map { ($0, []) })
        var highScores: [PopnNewHighScoreEntry] = []

        for record in latestRecords {
            let previous = previousByKey[key(record)]
            let previousMedal = previous?.medalEnum ?? .noPlay
            let previousRank = previous?.rank ?? PopnRank.none.rawValue
            let previousScore = previous?.score ?? 0
            let clearType = record.clearType.rawValue

            if trackedClearTypes.contains(clearType), clearType != previousMedal.clearType.rawValue {
                clears[clearType]?.append(PopnNewClearEntry(
                    songTitle: record.title,
                    level: record.level,
                    difficulty: record.difficultyEnum,
                    medal: record.medal,
                    previousMedal: previousMedal.rawValue
                ))
            }

            if trackedRanks.contains(record.rank), record.rank != previousRank {
                ranks[record.rank]?.append(PopnNewRankEntry(
                    songTitle: record.title,
                    level: record.level,
                    difficulty: record.difficultyEnum,
                    rank: record.rank,
                    previousRank: previousRank
                ))
            }

            if record.score > previousScore {
                highScores.append(PopnNewHighScoreEntry(
                    songTitle: record.title,
                    level: record.level,
                    difficulty: record.difficultyEnum,
                    newScore: record.score,
                    previousScore: previousScore,
                    newRank: record.rank,
                    previousRank: previousRank
                ))
            }
        }

        return (clears, highScores, ranks)
    }
}
