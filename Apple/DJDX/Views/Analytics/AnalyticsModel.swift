import OrderedCollections
import SwiftUI

@MainActor
@Observable
final class AnalyticsModel {

    // Overall
    var clearTypePerDifficulty: [Int: OrderedDictionary<String, Int>] = [:]
    var djLevelPerDifficulty: [Int: [IIDXDJLevel: Int]] = [:]

    // Trends
    var clearTypePerImportGroup: [Date: [Int: OrderedDictionary<String, Int>]] = [:]
    var djLevelPerImportGroup: [Date: [Int: OrderedDictionary<String, Int>]] = [:]
    var progressPerImportGroup: [IIDXProgressPoint] = []

    // New Clears & High Scores
    var newClears: [NewClearEntry] = []
    var newAssistClears: [NewClearEntry] = []
    var newEasyClears: [NewClearEntry] = []
    var newFullComboClears: [NewClearEntry] = []
    var newHardClears: [NewClearEntry] = []
    var newExHardClears: [NewClearEntry] = []
    var newFailed: [NewClearEntry] = []
    var newHighScores: [NewHighScoreEntry] = []
    var newClearLamps: [NewClearEntry] = []
    var newScoreUpdates: [NewHighScoreEntry] = []
    var newAAA: [NewDJLevelEntry] = []
    var newAA: [NewDJLevelEntry] = []
    var newA: [NewDJLevelEntry] = []

    // Suggestions
    var djLevelSuggestions: [IIDXDJLevelSuggestion] = []
    var clearLampSuggestionCandidates: [IIDXChartSuggestion] = []
    var longUnplayedSuggestions: [IIDXChartSuggestion] = []

    // Tower
    var towerEntries: [IIDXTowerEntry] = []

    var dataState: DataState = .initializing

    let fetcher = IIDXReader()
    let difficulties: [Int] = Array(1...12)
    let sessionStore: IIDXSessionStore?

    init(sessionStore: IIDXSessionStore? = nil) {
        self.sessionStore = sessionStore
    }

    var towerChartEntries: [IIDXTowerEntry] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        let recentEntries = towerEntries.prefix(while: { $0.playDate >= thirtyDaysAgo })
        if recentEntries.count >= 5 {
            return Array(recentEntries).reversed()
        }
        return Array(towerEntries.prefix(5)).reversed()
    }

    var towerTotalKeyCount: Int {
        towerEntries.reduce(0) { $0 + $1.keyCount } / 100
    }

    var towerTotalScratchCount: Int {
        towerEntries.reduce(0) { $0 + $1.scratchCount } / 100
    }

    typealias NewEntrySet = (
        clears: [String: [NewClearEntry]],
        highScores: [NewHighScoreEntry],
        clearLamps: [NewClearEntry],
        scoreUpdates: [NewHighScoreEntry],
        djLevels: [String: [NewDJLevelEntry]]
    )

    enum ReloadResult: Sendable {
        case counts(clearType: [String: [Int: [String: Int]]], djLevel: [String: [Int: [String: Int]]])
        case latest(newEntries: NewEntrySet?, suggestions: IIDXSuggestionSet)
        case progress([IIDXProgressPoint])
        case tower([IIDXTowerEntry])
    }

    func reload(playType: IIDXPlayType, iidxVersion: IIDXVersion, filters: FilterOptions? = nil) async {
        dataState = .loading
        if let sessionStore {
            await reloadFromLastSession(store: sessionStore, playType: playType)
            towerEntries = await fetcher.allTowerEntries()
            withAnimation(.smooth.speed(2.0)) {
                dataState = .presenting
            }
            return
        }
        let importGroups = await fetcher.importGroups(for: iidxVersion)
        await withTaskGroup(of: ReloadResult.self) { group in
            group.addTask {
                let result = await IIDXReader().aggregatedCounts(
                    for: importGroups.map(\.id), playType: playType, filters: filters
                )
                return .counts(clearType: result.clearType, djLevel: result.djLevel)
            }
            group.addTask {
                await Self.loadLatest(importGroups: importGroups, playType: playType, filters: filters)
            }
            group.addTask {
                .progress(await Self.loadProgress(importGroups: importGroups, playType: playType, filters: filters))
            }
            group.addTask {
                .tower(await IIDXReader().allTowerEntries())
            }
            for await result in group {
                apply(result, importGroups: importGroups)
            }
        }
        withAnimation(.smooth.speed(2.0)) {
            dataState = .presenting
        }
        await WidgetDataPublisher.shared.publishClearTypeAndDJLevel(
            playType: playType, iidxVersion: iidxVersion
        )
    }

    func apply(_ result: ReloadResult, importGroups: [ImportGroup]) {
        switch result {
        case .counts(let clearType, let djLevel):
            applyOverview(clearType: clearType, djLevel: djLevel, latestGroupID: importGroups.last?.id)
            applyTrends(clearType: clearType, djLevel: djLevel, importGroups: importGroups)
        case .latest(let newEntries, let suggestions):
            applyNewEntries(newEntries)
            withAnimation(.smooth.speed(2.0)) {
                djLevelSuggestions = suggestions.djLevels
                clearLampSuggestionCandidates = suggestions.clearLamps
                longUnplayedSuggestions = suggestions.longUnplayed
            }
        case .progress(let points):
            withAnimation(.smooth.speed(2.0)) {
                progressPerImportGroup = points
            }
        case .tower(let entries):
            towerEntries = entries
        }
    }

    func applyOverview(
        clearType: [String: [Int: [String: Int]]],
        djLevel: [String: [Int: [String: Int]]],
        latestGroupID: String?
    ) {
        if let latestGroupID, let rawClearType = clearType[latestGroupID], !rawClearType.isEmpty {
            let newClearType = buildOrderedClearType(from: rawClearType)
            let newDJLevelPerDifficulty = convertToEnumKeyed(buildOrderedDJLevel(from: djLevel[latestGroupID] ?? [:]))
            withAnimation(.smooth.speed(2.0)) {
                self.clearTypePerDifficulty = newClearType
                self.djLevelPerDifficulty = newDJLevelPerDifficulty
            }
        } else {
            withAnimation(.smooth.speed(2.0)) {
                self.clearTypePerDifficulty.removeAll()
                self.djLevelPerDifficulty.removeAll()
            }
        }
    }

    func applyTrends(
        clearType: [String: [Int: [String: Int]]],
        djLevel: [String: [Int: [String: Int]]],
        importGroups: [ImportGroup]
    ) {
        guard !importGroups.isEmpty else { return }
        var newClearTypeData: [Date: [Int: OrderedDictionary<String, Int>]] = [:]
        var newDJLevelData: [Date: [Int: OrderedDictionary<String, Int>]] = [:]
        for importGroup in importGroups {
            if let rawClearType = clearType[importGroup.id] {
                let ordered = buildOrderedClearType(from: rawClearType)
                if sumOfCounts(ordered) > 0 {
                    newClearTypeData[importGroup.importDate] = ordered
                }
            }
            if let rawDJLevel = djLevel[importGroup.id] {
                let ordered = buildOrderedDJLevel(from: rawDJLevel)
                if sumOfCounts(ordered) > 0 {
                    newDJLevelData[importGroup.importDate] = ordered
                }
            }
        }
        withAnimation(.smooth.speed(2.0)) {
            self.clearTypePerImportGroup = newClearTypeData
            self.djLevelPerImportGroup = newDJLevelData
        }
    }

    func applyNewEntries(_ computed: NewEntrySet?) {
        withAnimation(.smooth.speed(2.0)) {
            self.newClears = computed?.clears["CLEAR"] ?? []
            self.newEasyClears = computed?.clears["EASY CLEAR"] ?? []
            self.newAssistClears = computed?.clears["ASSIST CLEAR"] ?? []
            self.newFullComboClears = computed?.clears["FULLCOMBO CLEAR"] ?? []
            self.newHardClears = computed?.clears["HARD CLEAR"] ?? []
            self.newExHardClears = computed?.clears["EX HARD CLEAR"] ?? []
            self.newFailed = computed?.clears["FAILED"] ?? []
            self.newHighScores = computed?.highScores ?? []
            self.newClearLamps = computed?.clearLamps ?? []
            self.newScoreUpdates = computed?.scoreUpdates ?? []
            self.newAAA = computed?.djLevels["AAA"] ?? []
            self.newAA = computed?.djLevels["AA"] ?? []
            self.newA = computed?.djLevels["A"] ?? []
        }
    }

    nonisolated static func loadLatest(
        importGroups: [ImportGroup], playType: IIDXPlayType, filters: FilterOptions?
    ) async -> ReloadResult {
        async let songsTask = IIDXReader().songCompactTitles()
        async let latestTask = loadRecords(for: importGroups.last, playType: playType)
        async let previousTask = loadRecords(
            for: importGroups.count >= 2 ? importGroups[importGroups.count - 2] : nil, playType: playType
        )
        let latestRecords = await latestTask
        var newEntries: NewEntrySet?
        if importGroups.count >= 2 {
            newEntries = computeNewEntries(
                latestRecords: latestRecords.sorted { $0.lastPlayDate < $1.lastPlayDate },
                previousRecords: await previousTask,
                filters: filters
            )
        }
        let suggestions = computeSuggestions(
            records: latestRecords, songs: await songsTask, playType: playType, filters: filters
        )
        return .latest(newEntries: newEntries, suggestions: suggestions)
    }

    nonisolated static func loadRecords(for importGroup: ImportGroup?, playType: IIDXPlayType) async -> [IIDXSongRecord] {
        guard let importGroup else { return [] }
        return await IIDXReader().songRecords(for: importGroup.id, playType: playType)
    }

    nonisolated static func computeNewEntries(
        latestRecords: [IIDXSongRecord],
        previousRecords: [IIDXSongRecord],
        filters: FilterOptions? = nil
    ) -> (
        clears: [String: [NewClearEntry]],
        highScores: [NewHighScoreEntry],
        clearLamps: [NewClearEntry],
        scoreUpdates: [NewHighScoreEntry],
        djLevels: [String: [NewDJLevelEntry]]
    ) {
        var previousByTitle: [String: IIDXSongRecord] = [:]
        previousByTitle.reserveCapacity(previousRecords.count)
        for record in previousRecords {
            previousByTitle[Self.matchKey(for: record)] = record
        }
        var computedClears: [String: [NewClearEntry]] = [
            "CLEAR": [],
            "EASY CLEAR": [],
            "ASSIST CLEAR": [],
            "FULLCOMBO CLEAR": [],
            "HARD CLEAR": [],
            "EX HARD CLEAR": [],
            "FAILED": []
        ]
        var computedNewHighScores: [NewHighScoreEntry] = []
        var computedClearLamps: [NewClearEntry] = []
        var computedDJLevels: [String: [NewDJLevelEntry]] = [
            "AAA": [],
            "AA": [],
            "A": []
        ]

        let levels: [(IIDXLevel, KeyPath<IIDXSongRecord, IIDXLevelScore>)] = [
            (.beginner, \.beginnerScore),
            (.normal, \.normalScore),
            (.hyper, \.hyperScore),
            (.another, \.anotherScore),
            (.leggendaria, \.leggendariaScore)
        ]

        for latestRecord in latestRecords {
            if let versions = filters?.versions, !versions.isEmpty, !versions.contains(latestRecord.version) {
                continue
            }
            let previousRecord = previousByTitle[Self.matchKey(for: latestRecord)]

            for (level, keyPath) in levels {
                let latestScore = latestRecord[keyPath: keyPath]
                guard latestScore.difficulty > 0, latestScore.score > 0 else { continue }
                if let filters, !Self.score(latestScore, level: level, matches: filters) { continue }

                let previousScore = previousRecord?[keyPath: keyPath]
                let previousClearType = previousScore?.clearType ?? "NO PLAY"

                if let clearType = latestScore.clearType as String?,
                   computedClears.keys.contains(clearType),
                   previousClearType != clearType {
                    computedClears[clearType]!.append(NewClearEntry(
                        songRecord: latestRecord,
                        level: level,
                        score: latestScore,
                        previousClearType: previousClearType
                    ))
                }

                if Self.isClearLampImprovement(from: previousClearType, to: latestScore.clearType) {
                    computedClearLamps.append(NewClearEntry(
                        songRecord: latestRecord,
                        level: level,
                        score: latestScore,
                        previousClearType: previousClearType
                    ))
                }

                let previousDJLevel = previousScore?.djLevel ?? "---"
                if let djLevel = latestScore.djLevel as String?,
                   computedDJLevels.keys.contains(djLevel),
                   previousDJLevel != djLevel {
                    computedDJLevels[djLevel]!.append(NewDJLevelEntry(
                        songRecord: latestRecord,
                        level: level,
                        score: latestScore
                    ))
                }

                let previousScoreValue = previousScore?.score ?? 0
                if latestScore.score > previousScoreValue {
                    computedNewHighScores.append(NewHighScoreEntry(
                        songRecord: latestRecord,
                        level: level,
                        score: latestScore,
                        previousScore: previousScoreValue
                    ))
                }
            }
        }

        return (
            computedClears, computedNewHighScores, computedClearLamps,
            computedNewHighScores.filter { $0.previousScore > 0 }, computedDJLevels
        )
    }

    // MARK: - Helpers

    nonisolated static func isClearLampImprovement(from previous: String, to latest: String) -> Bool {
        let ranked = IIDXClearType.sortedStrings
        guard let latestRank = ranked.firstIndex(of: latest),
              latestRank < ranked.firstIndex(of: IIDXClearType.failed.rawValue)! else { return false }
        let previousRank = ranked.firstIndex(of: previous) ?? ranked.count
        return latestRank < previousRank
    }

    nonisolated static func score(_ score: IIDXLevelScore, level: IIDXLevel, matches filters: FilterOptions) -> Bool {
        if !filters.levels.isEmpty, !filters.levels.contains(level) { return false }
        if !filters.difficulties.isEmpty,
           !filters.difficulties.contains(where: { $0.rawValue == score.difficulty }) { return false }
        if !filters.clearTypes.isEmpty,
           !filters.clearTypes.contains(where: { $0.rawValue == score.clearType }) { return false }
        if !filters.djLevels.isEmpty,
           !filters.djLevels.contains(where: { $0.rawValue == score.djLevel }) { return false }
        return true
    }

    nonisolated static func matchKey(for record: IIDXSongRecord) -> String {
        record.titleCompact() + "\u{1}" + record.artist.compact
    }

    func convertToEnumKeyed(_ data: [Int: OrderedDictionary<String, Int>]) -> [Int: [IIDXDJLevel: Int]] {
        var result: [Int: [IIDXDJLevel: Int]] = [:]
        for (difficulty, counts) in data {
            var inner: [IIDXDJLevel: Int] = [:]
            for level in IIDXDJLevel.sorted {
                inner[level] = counts[level.rawValue] ?? 0
            }
            result[difficulty] = inner
        }
        return result
    }

    func sumOfCounts(_ data: [Int: OrderedDictionary<String, Int>]) -> Int {
        data.values.reduce(0) { sum, dict in
            sum + dict.values.reduce(0, +)
        }
    }

    func buildOrderedClearType(
        from raw: [Int: [String: Int]]
    ) -> [Int: OrderedDictionary<String, Int>] {
        let clearTypes = IIDXClearType.sortedStringsWithoutNoPlay
        var result: [Int: OrderedDictionary<String, Int>] = [:]
        for difficulty in difficulties {
            let counts = raw[difficulty] ?? [:]
            result[difficulty] = OrderedDictionary(
                uniqueKeys: clearTypes,
                values: clearTypes.map { counts[$0] ?? 0 }
            )
        }
        return result
    }

    func buildOrderedDJLevel(
        from raw: [Int: [String: Int]]
    ) -> [Int: OrderedDictionary<String, Int>] {
        let djLevels = Array(IIDXDJLevel.sortedStrings.reversed())
        var result: [Int: OrderedDictionary<String, Int>] = [:]
        for difficulty in difficulties {
            let counts = raw[difficulty] ?? [:]
            result[difficulty] = OrderedDictionary(
                uniqueKeys: djLevels,
                values: djLevels.map { counts[$0] ?? 0 }
            )
        }
        return result
    }
}
