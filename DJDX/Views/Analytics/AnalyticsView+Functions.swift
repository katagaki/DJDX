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
    func reloadScores() {
        dataState = .loading
        debugPrint("Calculating new values")
        let songRecords = calendar.latestAvailableIIDXSongRecords(in: modelContext)
            .filter { $0.playType == playTypeToShow }
        if songRecords.count == 0 {
            withAnimation(.snappy.speed(2.0)) {
                dataState = .presenting
            }
        } else {
            var newClearLampPerDifficulty: [Int: OrderedDictionary<String, Int>] = [:]
            var newScoresPerDifficulty: [Int: [IIDXDJLevel: Int]] = [:]
            for difficulty in difficulties {
                newScoresPerDifficulty[difficulty] = IIDXDJLevel.sorted
                    .reduce(into: [IIDXDJLevel: Int]()) { $0[$1] = 0 }
                newClearLampPerDifficulty[difficulty] = OrderedDictionary(
                    uniqueKeys: IIDXClearType.sortedStringsWithoutNoPlay,
                    values: IIDXClearType.sortedStringsWithoutNoPlay.map({ _ in return 0 })
                )
            }
            debugPrint(newClearLampPerDifficulty)

            // Fan out scores
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

            // Add scores to dictionary
            for score in scores {
                if score.djLevelEnum() != .none {
                    newScoresPerDifficulty[score.difficulty]?[score.djLevelEnum()]? += 1
                }
                if score.clearType != "NO PLAY" {
                    newClearLampPerDifficulty[score.difficulty]?[score.clearType]? += 1
                }
            }

            withAnimation(.snappy.speed(2.0)) {
                clearLampPerDifficulty.removeAll()
                scoreRatePerDifficulty.removeAll()
                newClearLampPerDifficulty.forEach { clearLampPerDifficulty[$0] = $1 }
                newScoresPerDifficulty.forEach { scoreRatePerDifficulty[$0] = $1 }
                dataState = .presenting
            }
        }
    }

    func reloadTrends() {
        let importGroups: [ImportGroup] = (try? modelContext.fetch(
            FetchDescriptor<ImportGroup>(
                sortBy: [SortDescriptor(\.importDate, order: .forward)]
            )
        )) ?? []
        if importGroups.count == 0 {
            withAnimation(.snappy.speed(2.0)) {
                dataState = .presenting
            }
        } else {
            // TODO: Do calculation
        }
    }
}
