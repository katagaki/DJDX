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

    // MARK: Data Fetching

    func fetchSongRecords(for importGroupID: String, playType: IIDXPlayType) -> [IIDXSongRecord] {
        let descriptor = FetchDescriptor<IIDXSongRecord>(
            predicate: #Predicate<IIDXSongRecord> {
                $0.importGroup?.id == importGroupID
            }
        )
        return ((try? modelContext.fetch(descriptor)) ?? []).filter { $0.playType == playType }
    }

    // MARK: Data Computation

    func computeAllCounts(from songRecords: [IIDXSongRecord]) -> (
        clearType: [Int: OrderedDictionary<String, Int>],
        djLevel: [Int: OrderedDictionary<String, Int>]
    ) {
        let clearTypes = IIDXClearType.sortedStringsWithoutNoPlay
        let djLevels = IIDXDJLevel.sortedStrings.reversed()

        var clearTypeResult: [Int: OrderedDictionary<String, Int>] = [:]
        var djLevelResult: [Int: OrderedDictionary<String, Int>] = [:]

        for difficulty in difficulties {
            clearTypeResult[difficulty] = OrderedDictionary(
                uniqueKeys: clearTypes,
                values: clearTypes.map { _ in 0 }
            )
            djLevelResult[difficulty] = OrderedDictionary(
                uniqueKeys: djLevels,
                values: djLevels.map { _ in 0 }
            )
        }

        for songRecord in songRecords {
            let scores: [IIDXLevelScore] = [
                songRecord.beginnerScore,
                songRecord.normalScore,
                songRecord.hyperScore,
                songRecord.anotherScore,
                songRecord.leggendariaScore
            ]
            for score in scores {
                if score.difficulty == 0 { continue }

                if score.clearType != "NO PLAY" && score.score > 0 {
                    clearTypeResult[score.difficulty]?[score.clearType]? += 1
                }

                if let djLevel = IIDXDJLevel(rawValue: score.djLevel), djLevel != .none {
                    djLevelResult[score.difficulty]?[score.djLevel]? += 1
                }
            }
        }

        return (clearTypeResult, djLevelResult)
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

    // MARK: Shared

    func trendData(using data: Data) -> [CachedTrendData] {
        (try? JSONDecoder().decode([CachedTrendData].self, from: data)) ?? []
    }

    func sumOfCounts(_ data: [Int: OrderedDictionary<String, Int>]) -> Int {
        data.values.reduce(0) { sum, dict in
            sum + dict.values.reduce(0, +)
        }
    }
}
