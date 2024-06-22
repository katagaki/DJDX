//
//  AnalyticsView+Functions.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/02.
//

import Foundation
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
            var newClearLampPerDifficulty: [Int: [String: Int]] = [:]
            var newScoresPerDifficulty: [Int: [IIDXDJLevel: Int]] = [:]
            for difficulty in difficulties {
                newScoresPerDifficulty[difficulty] = IIDXDJLevel.sorted
                    .reduce(into: [IIDXDJLevel: Int]()) { $0[$1] = 0 }
                newClearLampPerDifficulty[difficulty] = IIDXClearType.sortedStringsWithoutNoPlay
                    .reduce(into: [String: Int]()) { $0[$1] = 0 }
            }

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
}
