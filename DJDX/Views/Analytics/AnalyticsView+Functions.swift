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
        var result: [Int: OrderedDictionary<String, Int>] = [:]
        
        let clearTypes = IIDXClearType.sortedStringsWithoutNoPlay
        
        for difficulty in difficulties {
            result[difficulty] = OrderedDictionary(
                uniqueKeys: clearTypes,
                values: clearTypes.map({ _ in return 0 })
            )
            
            for clearType in clearTypes {
                var count = 0
                
                let beginner = FetchDescriptor<IIDXSongRecord>(predicate: #Predicate {
                    $0.importGroup?.id == importGroupID &&
                    $0.playType == playType &&
                    $0.beginnerScore.difficulty == difficulty &&
                    $0.beginnerScore.clearType == clearType
                })
                count += (try? modelContext.fetchCount(beginner)) ?? 0

                let normal = FetchDescriptor<IIDXSongRecord>(predicate: #Predicate {
                    $0.importGroup?.id == importGroupID &&
                    $0.playType == playType &&
                    $0.normalScore.difficulty == difficulty &&
                    $0.normalScore.clearType == clearType
                })
                count += (try? modelContext.fetchCount(normal)) ?? 0

                let hyper = FetchDescriptor<IIDXSongRecord>(predicate: #Predicate {
                    $0.importGroup?.id == importGroupID &&
                    $0.playType == playType &&
                    $0.hyperScore.difficulty == difficulty &&
                    $0.hyperScore.clearType == clearType
                })
                count += (try? modelContext.fetchCount(hyper)) ?? 0

                let another = FetchDescriptor<IIDXSongRecord>(predicate: #Predicate {
                    $0.importGroup?.id == importGroupID &&
                    $0.playType == playType &&
                    $0.anotherScore.difficulty == difficulty &&
                    $0.anotherScore.clearType == clearType
                })
                count += (try? modelContext.fetchCount(another)) ?? 0

                let leggendaria = FetchDescriptor<IIDXSongRecord>(predicate: #Predicate {
                    $0.importGroup?.id == importGroupID &&
                    $0.playType == playType &&
                    $0.leggendariaScore.difficulty == difficulty &&
                    $0.leggendariaScore.clearType == clearType
                })
                count += (try? modelContext.fetchCount(leggendaria)) ?? 0
                
                result[difficulty]?[clearType] = count
            }
        }
        return result
    }

    func countDJLevelPerDifficulty(
        for importGroupID: String,
        playType: IIDXPlayType
    ) -> [Int: OrderedDictionary<String, Int>] {
        var result: [Int: OrderedDictionary<String, Int>] = [:]
        
        let djLevels = IIDXDJLevel.sortedStrings.reversed()
        // Reversed because original code in djLevelPerDifficulty used reversed?
        // Line 194: let djLevels = IIDXDJLevel.sortedStrings.reversed()
        // Yes, preserving order.
        
        for difficulty in difficulties {
            result[difficulty] = OrderedDictionary(
                uniqueKeys: djLevels,
                values: djLevels.map({ _ in return 0 })
            )
            
            for djLevel in djLevels {
                var count = 0
                
                let beginner = FetchDescriptor<IIDXSongRecord>(predicate: #Predicate {
                    $0.importGroup?.id == importGroupID &&
                    $0.playType == playType &&
                    $0.beginnerScore.difficulty == difficulty &&
                    $0.beginnerScore.djLevel == djLevel
                })
                count += (try? modelContext.fetchCount(beginner)) ?? 0

                let normal = FetchDescriptor<IIDXSongRecord>(predicate: #Predicate {
                    $0.importGroup?.id == importGroupID &&
                    $0.playType == playType &&
                    $0.normalScore.difficulty == difficulty &&
                    $0.normalScore.djLevel == djLevel
                })
                count += (try? modelContext.fetchCount(normal)) ?? 0

                let hyper = FetchDescriptor<IIDXSongRecord>(predicate: #Predicate {
                    $0.importGroup?.id == importGroupID &&
                    $0.playType == playType &&
                    $0.hyperScore.difficulty == difficulty &&
                    $0.hyperScore.djLevel == djLevel
                })
                count += (try? modelContext.fetchCount(hyper)) ?? 0

                let another = FetchDescriptor<IIDXSongRecord>(predicate: #Predicate {
                    $0.importGroup?.id == importGroupID &&
                    $0.playType == playType &&
                    $0.anotherScore.difficulty == difficulty &&
                    $0.anotherScore.djLevel == djLevel
                })
                count += (try? modelContext.fetchCount(another)) ?? 0

                let leggendaria = FetchDescriptor<IIDXSongRecord>(predicate: #Predicate {
                    $0.importGroup?.id == importGroupID &&
                    $0.playType == playType &&
                    $0.leggendariaScore.difficulty == difficulty &&
                    $0.leggendariaScore.djLevel == djLevel
                })
                count += (try? modelContext.fetchCount(leggendaria)) ?? 0
                
                result[difficulty]?[djLevel] = count
            }
        }
        return result
    }
}
