import OrderedCollections
import SwiftUI

@MainActor
@Observable
final class GITADORAAnalyticsModel {

    var clearTypePerDifficulty: [GITADORADifficulty: OrderedDictionary<String, Int>] = [:]
    var rankPerDifficulty: [GITADORADifficulty: OrderedDictionary<String, Int>] = [:]
    var clearTypePerLevel: [Int: OrderedDictionary<String, Int>] = [:]
    var rankPerLevel: [Int: OrderedDictionary<String, Int>] = [:]

    var totalCharts: Int = 0
    var skill: String?
    var topSkillRecords: [GITADORASongRecord] = []

    var newHighScores: [GITADORANewHighScoreEntry] = []
    var newClears: [String: [GITADORANewClearEntry]] = [:]
    var newRanks: [String: [GITADORANewRankEntry]] = [:]

    nonisolated static let trackedClearTypes: [String] = [
        GITADORAClearType.clear.rawValue,
        GITADORAClearType.fullCombo.rawValue,
        GITADORAClearType.excellent.rawValue
    ]
    nonisolated static let trackedRanks: [String] = [
        GITADORARank.ss.rawValue,
        GITADORARank.s.rawValue
    ]

    var dataState: DataState = .initializing

    let fetcher = GITADORAReader()

    func reload(version: GITADORAVersion,
                instrument: GITADORAInstrument,
                filters: GITADORAFilterOptions? = nil) async {
        dataState = .loading
        let allRecords = await fetcher.latestSongRecords(for: version)
            .filter { $0.instrumentEnum == instrument }
        var records = allRecords
        if let filters {
            records = records.filter { filters.matches($0) }
        }

        let clearByDiff = Self.counts(of: records, keys: GITADORAClearType.sortedStringsWithoutNoPlay,
                                      value: \.clearType, group: { $0.difficultyEnum })
        let rankByDiff = Self.counts(of: records, keys: GITADORARank.sortedStrings,
                                     value: \.rank, group: { $0.difficultyEnum })
        let clearByLevel = Self.counts(of: records, keys: GITADORAClearType.sortedStringsWithoutNoPlay,
                                       value: \.clearType, group: { Int($0.levelValue) > 0 ? Int($0.levelValue) : nil })
        let rankByLevel = Self.counts(of: records, keys: GITADORARank.sortedStrings,
                                      value: \.rank, group: { Int($0.levelValue) > 0 ? Int($0.levelValue) : nil })

        let topSkill = Array(allRecords.filter { $0.skillValue > 0 }
            .sorted { $0.skillValue > $1.skillValue }
            .prefix(50))
        let cachedSkill = UserDefaults.standard.string(
            forKey: GITADORAImporter.skillKey(gameType: instrument.gameType)
        )
        let lastPlay = await computeLastPlay(version: version, instrument: instrument, filters: filters)

        withAnimation(.smooth.speed(2.0)) {
            self.clearTypePerDifficulty = clearByDiff
            self.rankPerDifficulty = rankByDiff
            self.clearTypePerLevel = clearByLevel
            self.rankPerLevel = rankByLevel
            self.totalCharts = records.count
            self.skill = cachedSkill
            self.topSkillRecords = topSkill
            self.newClears = lastPlay.clears
            self.newHighScores = lastPlay.highScores
            self.newRanks = lastPlay.ranks
            self.dataState = .presenting
        }
    }

    nonisolated static func counts<Group: Hashable>(
        of records: [GITADORASongRecord],
        keys: [String],
        value: KeyPath<GITADORASongRecord, String>,
        group: (GITADORASongRecord) -> Group?
    ) -> [Group: OrderedDictionary<String, Int>] {
        var result: [Group: OrderedDictionary<String, Int>] = [:]
        let empty = OrderedDictionary(uniqueKeys: keys, values: keys.map { _ in 0 })
        for record in records {
            let key = record[keyPath: value]
            guard keys.contains(key), let groupKey = group(record) else { continue }
            result[groupKey, default: empty][key]? += 1
        }
        return result
    }

    private func computeLastPlay(version: GITADORAVersion,
                                 instrument: GITADORAInstrument,
                                 filters: GITADORAFilterOptions?) async -> (
        clears: [String: [GITADORANewClearEntry]],
        highScores: [GITADORANewHighScoreEntry],
        ranks: [String: [GITADORANewRankEntry]]
    ) {
        let groups = await fetcher.importGroups(for: version)
        guard groups.count >= 2 else { return ([:], [], [:]) }
        var latestRecords = await fetcher.songRecords(for: groups[0].id)
            .filter { $0.instrumentEnum == instrument }
        if let filters {
            latestRecords = latestRecords.filter { filters.matches($0) }
        }
        let previousRecords = await fetcher.songRecords(for: groups[1].id)
            .filter { $0.instrumentEnum == instrument }
        return Self.computeNewEntries(latestRecords: latestRecords, previousRecords: previousRecords)
    }

    nonisolated static func computeNewEntries(
        latestRecords: [GITADORASongRecord],
        previousRecords: [GITADORASongRecord]
    ) -> (
        clears: [String: [GITADORANewClearEntry]],
        highScores: [GITADORANewHighScoreEntry],
        ranks: [String: [GITADORANewRankEntry]]
    ) {
        func key(_ record: GITADORASongRecord) -> String {
            "\(record.titleCompact())|\(record.instrument)|\(record.difficulty)"
        }

        var previousByKey: [String: GITADORASongRecord] = [:]
        for record in previousRecords {
            previousByKey[key(record)] = record
        }

        var clears: [String: [GITADORANewClearEntry]] =
            Dictionary(uniqueKeysWithValues: trackedClearTypes.map { ($0, []) })
        var ranks: [String: [GITADORANewRankEntry]] =
            Dictionary(uniqueKeysWithValues: trackedRanks.map { ($0, []) })
        var highScores: [GITADORANewHighScoreEntry] = []

        for record in latestRecords {
            let previous = previousByKey[key(record)]
            let previousClearType = previous?.clearType ?? GITADORAClearType.noPlay.rawValue
            let previousRank = previous?.rank ?? GITADORARank.none.rawValue

            if trackedClearTypes.contains(record.clearType), record.clearType != previousClearType {
                clears[record.clearType]?.append(GITADORANewClearEntry(
                    songTitle: record.title,
                    level: record.level,
                    difficulty: record.difficultyEnum,
                    clearType: record.clearType,
                    previousClearType: previousClearType
                ))
            }

            if trackedRanks.contains(record.rank), record.rank != previousRank {
                ranks[record.rank]?.append(GITADORANewRankEntry(
                    songTitle: record.title,
                    level: record.level,
                    difficulty: record.difficultyEnum,
                    rank: record.rank,
                    previousRank: previousRank
                ))
            }

            if record.achievementRateValue > (previous?.achievementRateValue ?? 0.0) {
                highScores.append(GITADORANewHighScoreEntry(
                    songTitle: record.title,
                    level: record.level,
                    difficulty: record.difficultyEnum,
                    newRate: record.achievementRate,
                    previousRate: previous?.achievementRate ?? "",
                    newRank: record.rank,
                    previousRank: previousRank
                ))
            }
        }

        return (clears, highScores, ranks)
    }
}
