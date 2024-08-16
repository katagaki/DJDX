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

    func reload() {
        dataState = .loading
        Task.detached(priority: .userInitiated) {
            let viewMode = await viewMode
            switch viewMode {
            case .overview: await reloadOverview()
            case .trends: await reloadTrends()
            }
            await MainActor.run {
                withAnimation(.snappy.speed(2.0)) {
                    dataState = .presenting
                }
            }
        }
    }

    @MainActor
    func reloadOverview() async {
        debugPrint("Calculating overview")
        let songRecords = calendar.latestAvailableIIDXSongRecords(
            in: modelContext,
            on: calendar.analyticsDate
        )
            .filter { $0.playType == playTypeToShow }
        if songRecords.count > 0 {
            let newClearTypePerDifficulty = clearTypePerDifficulty(for: songRecords)
            withAnimation(.snappy.speed(2.0)) {
                self.clearTypePerDifficulty = newClearTypePerDifficulty
            }
            let newScoresPerDifficulty = scoresPerDifficulty(for: songRecords)
            withAnimation(.snappy.speed(2.0)) {
                self.djLevelPerDifficulty = newScoresPerDifficulty
            }
        } else {
            withAnimation(.snappy.speed(2.0)) {
                self.clearTypePerDifficulty.removeAll()
                self.djLevelPerDifficulty.removeAll()
            }
        }
    }

    func reloadTrends() async {
        debugPrint("Calculating trends")
        let importGroups: [ImportGroup] = (try? modelContext.fetch(
            FetchDescriptor<ImportGroup>(
                sortBy: [SortDescriptor(\.importDate, order: .forward)]
            )
        )) ?? []
        if importGroups.count > 0 {
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
        get trendDataFrom: @escaping @Sendable ([IIDXSongRecord]) async -> [Int: OrderedDictionary<String, Int>]
    ) async -> (data: [Date: [Int: OrderedDictionary<String, Int>]], cache: [CachedTrendData]) {

        var newData: [Date: [Int: OrderedDictionary<String, Int>]] = [:]
        var newCache: [CachedTrendData] = []

        await withTaskGroup(of: (ImportGroup, [Int: OrderedDictionary<String, Int>]).self) { group in
            let existingCache = trendData(using: cacheData)

            // Determine whether to load new data for import group or just take from cache
            for importGroup in importGroups {
                let date = dateWithTimeSetToMidnight(importGroup.importDate)
                if let existingCacheData = existingCache.first(where: {
                    $0.importGroupID == importGroup.id && $0.playType == playTypeToShow
                }) {
                    group.addTask {
                        debugPrint("Returning from cache: \(date)")
                        return (importGroup, existingCacheData.data)
                    }
                } else {
                    group.addTask { [playTypeToShow] in
                        debugPrint("Processing data: \(date)")
                        let songRecords: [IIDXSongRecord] = importGroup.iidxData?.filter({
                            $0.playType == playTypeToShow
                        }) ?? []
                        let data = await trendDataFrom(songRecords)
                        return (importGroup, data)
                    }
                }
            }

            // Wait for results
            for await result in group {
                let (importGroup, trendData) = result
                if sumOfCounts(trendData) > 0 {
                    debugPrint("Adding: \(result.0.importDate)")
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
        }
        return (newData, newCache)
    }

    func trendDataForClearTypePerDifficulty(
        _ importGroups: [ImportGroup]
    ) async -> [Date: [Int: OrderedDictionary<String, Int>]] {
        let (newData, newCache) = await trendDataPerDifficulty(
            importGroups,
            using: clearTypePerImportGroupCache
        ) { songRecords in
            await clearTypePerDifficulty(for: songRecords)
        }
        
        debugPrint("Updating Clear Type cache")
        clearTypePerImportGroupCache = (try? JSONEncoder().encode(newCache)) ?? Data()

        return newData
    }

    func trendDataForDJLevelPerDifficulty(
        _ importGroups: [ImportGroup]
    ) async -> [Date: [Int: OrderedDictionary<String, Int>]] {
        let (newData, newCache) = await trendDataPerDifficulty(
            importGroups,
            using: djLevelPerImportGroupCache
        ) { songRecords in
            await djLevelPerDifficulty(for: songRecords)
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
        let scores = scores(in: songRecords).filter({ $0.clearType != "NO PLAY" })
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
