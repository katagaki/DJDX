//
//  AnalyticsView+Functions.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/02.
//

import OrderedCollections
import SwiftData
import SwiftUI

extension AnalyticsView {
    func reload() async {
        dataState = .loading
        try? await Task.sleep(for: .seconds(0.5))
        Task.detached {
            await reloadOverview()
            await reloadTrends()
            await reloadNewClearsAndHighScores()
            await MainActor.run {
                withAnimation(.snappy.speed(2.0)) {
                    dataState = .presenting
                }
            }
        }
    }

    func reloadOverview() async {
        debugPrint("Calculating overview")
        let actor = DataFetcher(modelContainer: sharedModelContainer)
        let importGroupIdentifier = await actor.importGroupIdentifier(for: .now)
        if let importGroupIdentifier,
           let importGroup = modelContext.model(for: importGroupIdentifier) as? ImportGroup {
            let songRecords = fetchSongRecords(for: importGroup.id, playType: playTypeToShow)
            if songRecords.count > 0 {
                let (newClearType, newDJLevel) = computeAllCounts(from: songRecords)
                let newDJLevelPerDifficulty = convertToEnumKeyed(newDJLevel)
                await MainActor.run {
                    withAnimation(.snappy.speed(2.0)) {
                        self.clearTypePerDifficulty = newClearType
                        self.djLevelPerDifficulty = newDJLevelPerDifficulty
                    }
                }
            } else {
                await MainActor.run {
                    withAnimation(.snappy.speed(2.0)) {
                        self.clearTypePerDifficulty.removeAll()
                        self.djLevelPerDifficulty.removeAll()
                    }
                }
            }
        }
    }

    // swiftlint:disable function_body_length
    func reloadTrends() async {
        debugPrint("Calculating trends")
        var importGroups: [ImportGroup] = (try? modelContext.fetch(
            FetchDescriptor<ImportGroup>(
                sortBy: [SortDescriptor(\.importDate, order: .forward)]
            )
        )) ?? []
        guard importGroups.count > 0 else { return }
        importGroups.removeAll(where: { $0.iidxVersion != iidxVersion })

        let existingClearTypeCache = trendData(using: clearTypePerImportGroupCache)
        let existingDJLevelCache = trendData(using: djLevelPerImportGroupCache)

        var newClearTypeData: [Date: [Int: OrderedDictionary<String, Int>]] = [:]
        var newDJLevelData: [Date: [Int: OrderedDictionary<String, Int>]] = [:]
        var newClearTypeCache: [CachedTrendData] = []
        var newDJLevelCache: [CachedTrendData] = []

        for importGroup in importGroups {
            let cachedClearType = existingClearTypeCache.first(where: {
                $0.importGroupID == importGroup.id && $0.playType == playTypeToShow
            })
            let cachedDJLevel = existingDJLevelCache.first(where: {
                $0.importGroupID == importGroup.id && $0.playType == playTypeToShow
            })

            let clearTypeData: [Int: OrderedDictionary<String, Int>]
            let djLevelData: [Int: OrderedDictionary<String, Int>]

            if let cachedClearType, let cachedDJLevel {
                debugPrint("Returning from cache: \(importGroup.importDate)")
                clearTypeData = cachedClearType.data
                djLevelData = cachedDJLevel.data
            } else {
                debugPrint("Processing data: \(importGroup.importDate)")
                let songRecords = fetchSongRecords(for: importGroup.id, playType: playTypeToShow)
                let computed = computeAllCounts(from: songRecords)
                clearTypeData = cachedClearType?.data ?? computed.clearType
                djLevelData = cachedDJLevel?.data ?? computed.djLevel
            }

            if sumOfCounts(clearTypeData) > 0 {
                debugPrint("Adding: \(importGroup.importDate)")
                newClearTypeData[importGroup.importDate] = clearTypeData
            }
            if sumOfCounts(djLevelData) > 0 {
                newDJLevelData[importGroup.importDate] = djLevelData
            }

            newClearTypeCache.append(cachedClearType ?? CachedTrendData(
                importGroupID: importGroup.id, playType: playTypeToShow, data: clearTypeData
            ))
            newDJLevelCache.append(cachedDJLevel ?? CachedTrendData(
                importGroupID: importGroup.id, playType: playTypeToShow, data: djLevelData
            ))
        }

        debugPrint("Updating trend caches")
        clearTypePerImportGroupCache = (try? JSONEncoder().encode(newClearTypeCache)) ?? Data()
        djLevelPerImportGroupCache = (try? JSONEncoder().encode(newDJLevelCache)) ?? Data()

        await MainActor.run {
            withAnimation(.snappy.speed(2.0)) {
                self.clearTypePerImportGroup = newClearTypeData
                self.djLevelPerImportGroup = newDJLevelData
            }
        }
    }
    // swiftlint:enable function_body_length

    // MARK: New Clears & High Scores
    // swiftlint:disable function_body_length
    func reloadNewClearsAndHighScores() async {
        debugPrint("Calculating new clears and high scores")
        var importGroups: [ImportGroup] = (try? modelContext.fetch(
            FetchDescriptor<ImportGroup>(
                sortBy: [SortDescriptor(\.importDate, order: .forward)]
            )
        )) ?? []
        importGroups.removeAll(where: { $0.iidxVersion != iidxVersion })

        guard importGroups.count >= 2 else {
            await MainActor.run {
                withAnimation(.snappy.speed(2.0)) {
                    self.newClears = []
                    self.newAssistClears = []
                    self.newEasyClears = []
                    self.newFullComboClears = []
                    self.newHardClears = []
                    self.newExHardClears = []
                    self.newFailed = []
                    self.newHighScores = []
                }
            }
            return
        }

        let latestGroup = importGroups[importGroups.count - 1]
        let previousGroup = importGroups[importGroups.count - 2]

        let latestRecords = fetchSongRecords(for: latestGroup.id, playType: playTypeToShow).sorted(by: {
            $0.lastPlayDate < $1.lastPlayDate
        })
        let previousRecords = fetchSongRecords(for: previousGroup.id, playType: playTypeToShow)

        // Build lookup by compact title for previous records
        var previousByTitle: [String: IIDXSongRecord] = [:]
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

                // Check for new clear type
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

                // Check for new high score
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

        await MainActor.run {
            withAnimation(.snappy.speed(2.0)) {
                self.newClears = computedClears["CLEAR"]!
                self.newEasyClears = computedClears["EASY CLEAR"]!
                self.newAssistClears = computedClears["ASSIST CLEAR"]!
                self.newFullComboClears = computedClears["FULLCOMBO CLEAR"]!
                self.newHardClears = computedClears["HARD CLEAR"]!
                self.newExHardClears = computedClears["EX HARD CLEAR"]!
                self.newFailed = computedClears["FAILED"]!
                self.newHighScores = computedNewHighScores
            }
        }
    }
    // swiftlint:enable function_body_length
}
