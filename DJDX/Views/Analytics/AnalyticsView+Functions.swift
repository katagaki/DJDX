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
        Task.detached(priority: .userInitiated) {
            let viewMode = await viewMode
            switch viewMode {
            case .overview: await reloadScores()
            case .trends: await reloadTrends()
            }
            await MainActor.run {
                withAnimation(.snappy.speed(2.0)) {
                    dataState = .presenting
                }
            }
        }
    }

    func reloadScores() async {
        dataState = .loading
        debugPrint("Calculating overview")
        let songRecords = calendar.latestAvailableIIDXSongRecords(in: modelContext)
            .filter { $0.playType == playTypeToShow }
        if songRecords.count > 0 {
            await withDiscardingTaskGroup { group in
                group.addTask {
                    let newClearLampPerDifficulty = await clearLampPerDifficulty(for: songRecords)
                    await MainActor.run {
                        withAnimation(.snappy.speed(2.0)) {
                            self.clearLampPerDifficulty = newClearLampPerDifficulty
                        }
                    }
                }
                group.addTask {
                    let newScoresPerDifficulty = await scoresPerDifficulty(for: songRecords)
                    await MainActor.run { [newScoresPerDifficulty] in
                        withAnimation(.snappy.speed(2.0)) {
                            self.scoreRatePerDifficulty = newScoresPerDifficulty
                        }
                    }
                }
            }
        } else {
            await MainActor.run {
                withAnimation(.snappy.speed(2.0)) {
                    self.clearLampPerDifficulty.removeAll()
                    self.scoreRatePerDifficulty.removeAll()
                }
            }
        }
    }

    func reloadTrends() async {
        dataState = .loading
        debugPrint("Calculating trends")
        let importGroups: [ImportGroup] = (try? modelContext.fetch(
            FetchDescriptor<ImportGroup>(
                sortBy: [SortDescriptor(\.importDate, order: .forward)]
            )
        )) ?? []
        if importGroups.count > 0 {
            var newClearLampPerImportGroup: [Date: [Int: OrderedDictionary<String, Int>]] = [:]
            await withTaskGroup(of: (ImportGroup, [Int: OrderedDictionary<String, Int>]).self) { group in
                var cachedData: [String: [Int: OrderedDictionary<String, Int>]] = [:]
                if let decodedCachedData = try? JSONDecoder().decode(
                    [String: [Int: OrderedDictionary<String, Int>]].self,
                    from: clearLampPerImportGroupCache
                ) {
                    cachedData = decodedCachedData
                }
                for importGroup in importGroups {
                    let date = dateWithTimeSetToMidnight(importGroup.importDate)
                    if let clearLampPerDifficultyForImportGroup = cachedData[importGroup.id] {
                        group.addTask {
                            debugPrint("Returning from cache: \(date)")
                            return (importGroup, clearLampPerDifficultyForImportGroup)
                        }
                    } else {
                        group.addTask { [playTypeToShow] in
                            debugPrint("Processing: \(date)")
                            let songRecords = importGroup.iidxData?.filter({ $0.playType == playTypeToShow }) ?? []
                            let clearLampPerDifficultyForImportGroup = await clearLampPerDifficulty(for: songRecords)
                            return (importGroup, clearLampPerDifficultyForImportGroup)
                        }
                    }
                }
                for await result in group {
                    let (importGroup, clearLampPerDifficultyForImportGroup) = result
                    newClearLampPerImportGroup[importGroup.importDate] = clearLampPerDifficultyForImportGroup
                    debugPrint("Processed: \(result.0)")
                    if cachedData[importGroup.id] == nil {
                        debugPrint("Storing to cache: \(importGroup.importDate)")
                        cachedData[importGroup.id] = clearLampPerDifficultyForImportGroup
                    }
                }
                do {
                    debugPrint("Updating cache")
                    // TODO: Invalidate cache for import groups that have been deleted
                    clearLampPerImportGroupCache = try JSONEncoder().encode(cachedData)
                } catch {
                    debugPrint("Could not update cache: \(error)")
                }
            }
            await MainActor.run {
                withAnimation(.snappy.speed(2.0)) {
                    self.clearLampPerImportGroup = newClearLampPerImportGroup
                }
            }
        }
    }

    func clearLampPerDifficulty(for songRecords: [IIDXSongRecord]) -> [Int: OrderedDictionary<String, Int>] {
        // Generate skeleton for calculation
        let clearTypes = IIDXClearType.sortedStringsWithoutNoPlay
        var newClearLampPerDifficulty: [Int: OrderedDictionary<String, Int>] = [:]
        for difficulty in difficulties {
            newClearLampPerDifficulty[difficulty] = OrderedDictionary(
                uniqueKeys: clearTypes,
                values: clearTypes.map({ _ in return 0 })
            )
        }

        // Add scores to dictionary
        let scores = scores(in: songRecords).filter({ $0.clearType != "NO PLAY" })
        for score in scores {
            newClearLampPerDifficulty[score.difficulty]?[score.clearType]? += 1
        }

        return newClearLampPerDifficulty
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

    func dateWithTimeSetToMidnight(_ date: Date) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = .current
        return calendar.date(
            from: Calendar.current.dateComponents([.year, .month, .day], from: date)
        ) ?? date
    }
}
