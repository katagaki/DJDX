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

    // New Clears & High Scores
    var newClears: [NewClearEntry] = []
    var newAssistClears: [NewClearEntry] = []
    var newEasyClears: [NewClearEntry] = []
    var newFullComboClears: [NewClearEntry] = []
    var newHardClears: [NewClearEntry] = []
    var newExHardClears: [NewClearEntry] = []
    var newFailed: [NewClearEntry] = []
    var newHighScores: [NewHighScoreEntry] = []
    var newAAA: [NewDJLevelEntry] = []
    var newAA: [NewDJLevelEntry] = []
    var newA: [NewDJLevelEntry] = []

    // Tower
    var towerEntries: [IIDXTowerEntry] = []

    var dataState: DataState = .initializing

    let fetcher = DataFetcher()
    let difficulties: [Int] = Array(1...12)

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

    func reload(playType: IIDXPlayType, iidxVersion: IIDXVersion) async {
        dataState = .loading
        try? await Task.sleep(for: .seconds(0.5))
        await reloadOverview(playType: playType, iidxVersion: iidxVersion)
        await reloadTrends(playType: playType, iidxVersion: iidxVersion)
        await reloadNewClearsAndHighScores(playType: playType, iidxVersion: iidxVersion)
        towerEntries = await fetcher.allTowerEntries()
        await WidgetDataPublisher.shared.publishClearTypeAndDJLevel(
            playType: playType, iidxVersion: iidxVersion
        )
        withAnimation(.snappy.speed(2.0)) {
            dataState = .presenting
        }
    }

    func reloadOverview(playType: IIDXPlayType, iidxVersion: IIDXVersion) async {
        debugPrint("Calculating overview")
        let importGroupID = await fetcher.importGroups(for: iidxVersion).last?.id
        if let importGroupID {
            let result = await fetcher.aggregatedCounts(
                for: [importGroupID], playType: playType
            )
            let rawClearType = result.clearType[importGroupID]
            let rawDJLevel = result.djLevel[importGroupID]

            if let rawClearType, !rawClearType.isEmpty {
                let newClearType = buildOrderedClearType(from: rawClearType)
                let newDJLevel = buildOrderedDJLevel(from: rawDJLevel ?? [:])
                let newDJLevelPerDifficulty = convertToEnumKeyed(newDJLevel)
                withAnimation(.snappy.speed(2.0)) {
                    self.clearTypePerDifficulty = newClearType
                    self.djLevelPerDifficulty = newDJLevelPerDifficulty
                }
            } else {
                withAnimation(.snappy.speed(2.0)) {
                    self.clearTypePerDifficulty.removeAll()
                    self.djLevelPerDifficulty.removeAll()
                }
            }
        } else {
            withAnimation(.snappy.speed(2.0)) {
                self.clearTypePerDifficulty.removeAll()
                self.djLevelPerDifficulty.removeAll()
            }
        }
    }

    func reloadTrends(playType: IIDXPlayType, iidxVersion: IIDXVersion) async {
        debugPrint("Calculating trends")
        let importGroups = await fetcher.importGroups(for: iidxVersion)
        guard !importGroups.isEmpty else { return }

        let importGroupIDs = importGroups.map(\.id)
        let idToDate = Dictionary(uniqueKeysWithValues: importGroups.map { ($0.id, $0.importDate) })

        let result = await fetcher.aggregatedCounts(for: importGroupIDs, playType: playType)

        var newClearTypeData: [Date: [Int: OrderedDictionary<String, Int>]] = [:]
        var newDJLevelData: [Date: [Int: OrderedDictionary<String, Int>]] = [:]

        for igID in importGroupIDs {
            guard let date = idToDate[igID] else { continue }

            if let rawClearType = result.clearType[igID] {
                let ordered = buildOrderedClearType(from: rawClearType)
                if sumOfCounts(ordered) > 0 {
                    newClearTypeData[date] = ordered
                }
            }
            if let rawDJLevel = result.djLevel[igID] {
                let ordered = buildOrderedDJLevel(from: rawDJLevel)
                if sumOfCounts(ordered) > 0 {
                    newDJLevelData[date] = ordered
                }
            }
        }

        withAnimation(.snappy.speed(2.0)) {
            self.clearTypePerImportGroup = newClearTypeData
            self.djLevelPerImportGroup = newDJLevelData
        }
    }

    func reloadNewClearsAndHighScores(playType: IIDXPlayType, iidxVersion: IIDXVersion) async {
        debugPrint("Calculating new clears and high scores")
        let importGroups = await fetcher.importGroups(for: iidxVersion)

        guard importGroups.count >= 2 else {
            withAnimation(.snappy.speed(2.0)) {
                self.newClears = []
                self.newAssistClears = []
                self.newEasyClears = []
                self.newFullComboClears = []
                self.newHardClears = []
                self.newExHardClears = []
                self.newFailed = []
                self.newHighScores = []
                self.newAAA = []
                self.newAA = []
                self.newA = []
            }
            return
        }

        let latestGroup = importGroups[importGroups.count - 1]
        let previousGroup = importGroups[importGroups.count - 2]

        async let latestRecordsTask = fetcher.songRecords(
            for: latestGroup.id, playType: playType
        )
        async let previousRecordsTask = fetcher.songRecords(
            for: previousGroup.id, playType: playType
        )

        let latestRecords = await latestRecordsTask.sorted(by: {
            $0.lastPlayDate < $1.lastPlayDate
        })
        let previousRecords = await previousRecordsTask

        let computed = Self.computeNewEntries(latestRecords: latestRecords, previousRecords: previousRecords)

        withAnimation(.snappy.speed(2.0)) {
            self.newClears = computed.clears["CLEAR"]!
            self.newEasyClears = computed.clears["EASY CLEAR"]!
            self.newAssistClears = computed.clears["ASSIST CLEAR"]!
            self.newFullComboClears = computed.clears["FULLCOMBO CLEAR"]!
            self.newHardClears = computed.clears["HARD CLEAR"]!
            self.newExHardClears = computed.clears["EX HARD CLEAR"]!
            self.newFailed = computed.clears["FAILED"]!
            self.newHighScores = computed.highScores
            self.newAAA = computed.djLevels["AAA"]!
            self.newAA = computed.djLevels["AA"]!
            self.newA = computed.djLevels["A"]!
        }
    }

    // swiftlint:disable function_body_length
    nonisolated static func computeNewEntries(
        latestRecords: [IIDXSongRecord],
        previousRecords: [IIDXSongRecord]
    ) -> (
        clears: [String: [NewClearEntry]],
        highScores: [NewHighScoreEntry],
        djLevels: [String: [NewDJLevelEntry]]
    ) {
        var previousByTitle: [String: IIDXSongRecord] = [:]
        previousByTitle.reserveCapacity(previousRecords.count)
        for record in previousRecords {
            previousByTitle[record.titleCompact()] = record
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
            let compactTitle = latestRecord.titleCompact()
            let previousRecord = previousByTitle[compactTitle]

            for (level, keyPath) in levels {
                let latestScore = latestRecord[keyPath: keyPath]
                guard latestScore.difficulty > 0, latestScore.score > 0 else { continue }

                let previousScore = previousRecord?[keyPath: keyPath]
                let previousClearType = previousScore?.clearType ?? "NO PLAY"

                if let clearType = latestScore.clearType as String?,
                   computedClears.keys.contains(clearType),
                   previousClearType != clearType {
                    computedClears[clearType]!.append(NewClearEntry(
                        songTitle: latestRecord.title,
                        songArtist: latestRecord.artist,
                        level: level,
                        difficulty: latestScore.difficulty,
                        clearType: clearType,
                        previousClearType: previousClearType
                    ))
                }

                let previousDJLevel = previousScore?.djLevel ?? "---"
                if let djLevel = latestScore.djLevel as String?,
                   computedDJLevels.keys.contains(djLevel),
                   previousDJLevel != djLevel {
                    computedDJLevels[djLevel]!.append(NewDJLevelEntry(
                        songTitle: latestRecord.title,
                        songArtist: latestRecord.artist,
                        level: level,
                        difficulty: latestScore.difficulty,
                        djLevel: djLevel,
                        previousDJLevel: previousDJLevel
                    ))
                }

                let previousScoreValue = previousScore?.score ?? 0
                if latestScore.score > previousScoreValue {
                    computedNewHighScores.append(NewHighScoreEntry(
                        songTitle: latestRecord.title,
                        songArtist: latestRecord.artist,
                        level: level,
                        difficulty: latestScore.difficulty,
                        newScore: latestScore.score,
                        previousScore: previousScoreValue,
                        newDJLevel: latestScore.djLevel,
                        previousDJLevel: previousScore?.djLevel ?? "---"
                    ))
                }
            }
        }

        return (computedClears, computedNewHighScores, computedDJLevels)
    }
    // swiftlint:enable function_body_length

    // MARK: - Helpers

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
