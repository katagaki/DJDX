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
            
            let newClearTypePerDifficulty = countClearTypePerDifficulty(for: importGroupID, playType: playTypeToShow)
            let newDJLevelPerDifficulty = countDJLevelPerDifficulty(for: importGroupID, playType: playTypeToShow)
            
            // Convert to [Int: [IIDXDJLevel: Int]] for the view
            var convertedDJLevelPerDifficulty: [Int: [IIDXDJLevel: Int]] = [:]
            for (difficulty, data) in newDJLevelPerDifficulty {
                var inner: [IIDXDJLevel: Int] = [:]
                // Initialize with 0
                for level in IIDXDJLevel.sorted {
                    inner[level] = 0
                }
                for (key, count) in data {
                     if let level = IIDXDJLevel(rawValue: key) {
                         inner[level] = count
                     }
                }
                convertedDJLevelPerDifficulty[difficulty] = inner
            }

            await MainActor.run {
                withAnimation(.snappy.speed(2.0)) {
                    self.clearTypePerDifficulty = newClearTypePerDifficulty
                    self.djLevelPerDifficulty = convertedDJLevelPerDifficulty
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
        get trendDataFrom: @escaping (String) async -> [Int: OrderedDictionary<String, Int>]
    ) async -> (data: [Date: [Int: OrderedDictionary<String, Int>]], cache: [CachedTrendData]) {

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
                let data = await trendDataFrom(importGroup.id)
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
        let (newData, newCache) = await trendDataPerDifficulty(
            importGroups,
            using: clearTypePerImportGroupCache
        ) { importGroupID in
            countClearTypePerDifficulty(for: importGroupID, playType: playTypeToShow)
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
        ) { importGroupID in
            countDJLevelPerDifficulty(for: importGroupID, playType: playTypeToShow)
        }

        debugPrint("Updating DJ Level trend cache")
        djLevelPerImportGroupCache = (try? JSONEncoder().encode(newCache)) ?? Data()

        return newData
    }

    // MARK: Shared


    func trendData(using data: Data) -> [CachedTrendData] {
        if let decodedCachedData = try? JSONDecoder().decode([CachedTrendData].self, from: data) {
            return decodedCachedData
        } else {
            return []
        }
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

    // MARK: Optimized Fetching

    func countClearTypePerDifficulty(
        for importGroupID: String,
        playType: IIDXPlayType
    ) -> [Int: OrderedDictionary<String, Int>] {
        // Fetch records filtering by import group and play type
        // We cannot filter by score properties in the predicate because IIDXLevelScore is a struct (stored as BLOB)
        let descriptor = FetchDescriptor<IIDXSongRecord>(
            predicate: #Predicate {
                $0.importGroup?.id == importGroupID &&
                $0.playType == playType
            }
        )
        let songRecords = (try? modelContext.fetch(descriptor)) ?? []

        // Generate skeleton for calculation
        let clearTypes = IIDXClearType.sortedStringsWithoutNoPlay
        var result: [Int: OrderedDictionary<String, Int>] = [:]
        for difficulty in difficulties {
            result[difficulty] = OrderedDictionary(
                uniqueKeys: clearTypes,
                values: clearTypes.map({ _ in return 0 })
            )
        }

        // Add scores to dictionary
        // Re-using logic from original implementation but cleaner
        for songRecord in songRecords {
            let scoresAvailable: [IIDXLevelScore] = [
                songRecord.beginnerScore,
                songRecord.normalScore,
                songRecord.hyperScore,
                songRecord.anotherScore,
                songRecord.leggendariaScore
            ]
            
            for score in scoresAvailable {
                // Filter invalid scores
                if score.difficulty == 0 { continue }
                if score.clearType == "NO PLAY" { continue }
                if score.score == 0 { continue }
                
                result[score.difficulty]?[score.clearType]? += 1
            }
        }

        return result
    }

    func countDJLevelPerDifficulty(
        for importGroupID: String,
        playType: IIDXPlayType
    ) -> [Int: OrderedDictionary<String, Int>] {
        // Fetch records filtering by import group and play type
        let descriptor = FetchDescriptor<IIDXSongRecord>(
            predicate: #Predicate {
                $0.importGroup?.id == importGroupID &&
                $0.playType == playType
            }
        )
        let songRecords = (try? modelContext.fetch(descriptor)) ?? []

        // Generate skeleton for calculation
        let djLevels = IIDXDJLevel.sortedStrings.reversed()
        var result: [Int: OrderedDictionary<String, Int>] = [:]
        for difficulty in difficulties {
            result[difficulty] = OrderedDictionary(
                uniqueKeys: djLevels,
                values: djLevels.map({ _ in return 0 })
            )
        }

        // Add scores to dictionary
        for songRecord in songRecords {
            let scoresAvailable: [IIDXLevelScore] = [
                songRecord.beginnerScore,
                songRecord.normalScore,
                songRecord.hyperScore,
                songRecord.anotherScore,
                songRecord.leggendariaScore
            ]
            
            for score in scoresAvailable {
                if score.difficulty == 0 { continue }
                
                // Assuming we want to count even if score is 0? 
                // Original code: scores(in: songRecords).filter({ $0.djLevelEnum() != .none})
                // djLevelEnum() returns .none if rawValue is "---".
                
                if let djLevel = IIDXDJLevel(rawValue: score.djLevel), djLevel != .none {
                   result[score.difficulty]?[score.djLevel]? += 1
                }
            }
        }

        return result
    }
}
