//
//  AnalyticsView+Functions.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/02.
//

import Foundation
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
            let importGroupID = importGroup.id
            var songRecords: [IIDXSongRecord] = (try? modelContext.fetch(
                FetchDescriptor<IIDXSongRecord>(
                    predicate: #Predicate<IIDXSongRecord> {
                        $0.importGroup?.id == importGroupID
                    },
                    sortBy: [SortDescriptor(\.title, order: .forward)]
                )
            )) ?? []
            songRecords.removeAll { $0.playType != playTypeToShow }
            if songRecords.count > 0 {
                let newClearTypePerDifficulty = clearTypePerDifficulty(for: songRecords)
                let newScoresPerDifficulty = scoresPerDifficulty(for: songRecords)
                await MainActor.run {
                    withAnimation(.snappy.speed(2.0)) {
                        self.clearTypePerDifficulty = newClearTypePerDifficulty
                        self.djLevelPerDifficulty = newScoresPerDifficulty
                    }
                }
            } else {
                withAnimation(.snappy.speed(2.0)) {
                    self.clearTypePerDifficulty.removeAll()
                    self.djLevelPerDifficulty.removeAll()
                }
            }
        }
    }

    func reloadTrends() async {
        debugPrint("Calculating trends")
        var importGroups: [ImportGroup] = (try? modelContext.fetch(
            FetchDescriptor<ImportGroup>(
                sortBy: [SortDescriptor(\.importDate, order: .forward)]
            )
        )) ?? []
        if importGroups.count > 0 {
            importGroups.removeAll(where: {$0.iidxVersion != iidxVersion})
            let newClearTypePerImportGroup = await trendDataForClearTypePerDifficulty(importGroups)
            let newDJLevelPerImportGroup = await trendDataForDJLevelPerDifficulty(importGroups)

            await MainActor.run {
                withAnimation(.snappy.speed(2.0)) {
                    self.clearTypePerImportGroup = newClearTypePerImportGroup
                    self.djLevelPerImportGroup = newDJLevelPerImportGroup
                }
            }
        }
    }

    // MARK: Trends

    func trendDataPerDifficulty(
        _ importGroups: [ImportGroup],
        using cacheData: Data,
        get trendDataFrom: @escaping ([IIDXSongRecord]) -> [Int: OrderedDictionary<String, Int>]
    ) -> (data: [Date: [Int: OrderedDictionary<String, Int>]], cache: [CachedTrendData]) {

        let existingCache = trendData(using: cacheData)
        var newData: [Date: [Int: OrderedDictionary<String, Int>]] = [:]
        var newCache: [CachedTrendData] = []
        var calculatedTrendData: [(importGroup: ImportGroup, data: [Int: OrderedDictionary<String, Int>])] = []

        // Determine whether to load new data for import group or just take from cache
        for importGroup in importGroups {
            let date = dateWithTimeSetToMidnight(importGroup.importDate)
            if let existingCacheData = existingCache.first(where: {
                $0.importGroupID == importGroup.id && $0.playType == playTypeToShow
            }) {
                debugPrint("Returning from cache: \(date)")
                calculatedTrendData.append((importGroup, existingCacheData.data))
            } else {
                debugPrint("Processing data: \(date)")
                let songRecords: [IIDXSongRecord] = importGroup.iidxData?.filter({
                    $0.playType == playTypeToShow
                }) ?? []
                let data = trendDataFrom(songRecords)
                calculatedTrendData.append((importGroup, data))
            }
        }

        for (importGroup, trendData) in calculatedTrendData {
            if sumOfCounts(trendData) > 0 {
                debugPrint("Adding: \(importGroup.importDate)")
                newData[importGroup.importDate] = trendData
            }
            if let existingCacheData = existingCache.first(where: {
                $0.importGroupID == importGroup.id && $0.playType == playTypeToShow
            }) {
                debugPrint("Storing existing data to new cache: \(importGroup.importDate)")
                newCache.append(existingCacheData)
            } else {
                debugPrint("Storing new data to new cache: \(importGroup.importDate)")
                newCache.append(
                    CachedTrendData(importGroupID: importGroup.id,
                                    playType: playTypeToShow,
                                    data: trendData)
                )
            }
        }

        return (newData, newCache)
    }

    func trendDataForClearTypePerDifficulty(
        _ importGroups: [ImportGroup]
    ) async -> [Date: [Int: OrderedDictionary<String, Int>]] {
        let (newData, newCache) = trendDataPerDifficulty(
            importGroups,
            using: clearTypePerImportGroupCache
        ) { songRecords in
            clearTypePerDifficulty(for: songRecords)
        }

        debugPrint("Updating Clear Type cache")
        clearTypePerImportGroupCache = (try? JSONEncoder().encode(newCache)) ?? Data()

        return newData
    }

    func trendDataForDJLevelPerDifficulty(
        _ importGroups: [ImportGroup]
    ) async -> [Date: [Int: OrderedDictionary<String, Int>]] {
        let (newData, newCache) = trendDataPerDifficulty(
            importGroups,
            using: djLevelPerImportGroupCache
        ) { songRecords in
            djLevelPerDifficulty(for: songRecords)
        }

        debugPrint("Updating DJ Level trend cache")
        djLevelPerImportGroupCache = (try? JSONEncoder().encode(newCache)) ?? Data()

        return newData
    }

    // MARK: Overview

    func clearTypePerDifficulty(for songRecords: [IIDXSongRecord]) -> [Int: OrderedDictionary<String, Int>] {
        // Generate skeleton for calculation
        let clearTypes = IIDXClearType.sortedStringsWithoutNoPlay
        var newClearTypePerDifficulty: [Int: OrderedDictionary<String, Int>] = [:]
        for difficulty in difficulties {
            newClearTypePerDifficulty[difficulty] = OrderedDictionary(
                uniqueKeys: clearTypes,
                values: clearTypes.map({ _ in return 0 })
            )
        }

        // Add scores to dictionary
        let scores = scores(in: songRecords).filter({ $0.clearType != "NO PLAY" && $0.score > 0 })
        for score in scores {
            newClearTypePerDifficulty[score.difficulty]?[score.clearType]? += 1
        }

        return newClearTypePerDifficulty
    }

    func djLevelPerDifficulty(for songRecords: [IIDXSongRecord]) -> [Int: OrderedDictionary<String, Int>] {
        // Generate skeleton for calculation
        let djLevels = IIDXDJLevel.sortedStrings.reversed()
        var newDJLevelForDifficulty: [Int: OrderedDictionary<String, Int>] = [:]
        for difficulty in difficulties {
            newDJLevelForDifficulty[difficulty] = OrderedDictionary(
                uniqueKeys: djLevels,
                values: djLevels.map({ _ in return 0 })
            )
        }

        // Add scores to dictionary
        for songRecord in songRecords {
            let scores: [IIDXLevelScore] = songRecord.scores()
            for score in scores {
                newDJLevelForDifficulty[score.difficulty]?[score.djLevel]? += 1
            }
        }

        return newDJLevelForDifficulty
    }

    func scoresPerDifficulty(for songRecords: [IIDXSongRecord]) -> [Int: [IIDXDJLevel: Int]] {
        // Generate skeleton for calculation
        var newScoresPerDifficulty: [Int: [IIDXDJLevel: Int]] = [:]
        for difficulty in difficulties {
            newScoresPerDifficulty[difficulty] = IIDXDJLevel.sorted
                .reduce(into: [IIDXDJLevel: Int]()) { $0[$1] = 0 }
        }

        // Add scores to dictionary
        let scores = scores(in: songRecords).filter({ $0.djLevelEnum() != .none})
        for score in scores {
            newScoresPerDifficulty[score.difficulty]?[score.djLevelEnum()]? += 1
        }
        return newScoresPerDifficulty
    }

    // MARK: Shared

    func trendData(using data: Data) -> [CachedTrendData] {
        if let decodedCachedData = try? JSONDecoder().decode([CachedTrendData].self, from: data) {
            return decodedCachedData
        } else {
            return []
        }
    }

    func scores(in songRecords: [IIDXSongRecord]) -> [IIDXLevelScore] {
        var scores: [IIDXLevelScore] = []
        for songRecord in songRecords {
            let scoresAvailable: [IIDXLevelScore] = [
                songRecord.beginnerScore,
                songRecord.normalScore,
                songRecord.hyperScore,
                songRecord.anotherScore,
                songRecord.leggendariaScore
            ]
                .filter({$0.difficulty != 0})
            scores.append(contentsOf: scoresAvailable)
        }
        return scores
    }

    func sumOfCounts(_ data: [Int: OrderedDictionary<String, Int>]) -> Int {
        var sum = 0
        for (_, clearTypeDictionary) in data {
            for (_, count) in clearTypeDictionary {
                sum += count
            }
        }
        return sum
    }

    func dateWithTimeSetToMidnight(_ date: Date) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = .current
        return calendar.date(
            from: Calendar.current.dateComponents([.year, .month, .day], from: date)
        ) ?? date
    }
}
