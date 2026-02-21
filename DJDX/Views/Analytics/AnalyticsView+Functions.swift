//
//  AnalyticsView+Functions.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/02.
//

import OrderedCollections
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
        let importGroupID = await fetcher.importGroupID(for: .now)
        if let importGroupID {
            let songRecords = await fetcher.songRecords(for: importGroupID, playType: playTypeToShow)
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
        var importGroups = await fetcher.allImportGroups()
        guard importGroups.count > 0 else { return }
        importGroups.removeAll(where: { $0.iidxVersion != iidxVersion })

        var newClearTypeData: [Date: [Int: OrderedDictionary<String, Int>]] = [:]
        var newDJLevelData: [Date: [Int: OrderedDictionary<String, Int>]] = [:]

        for importGroup in importGroups {
            debugPrint("Processing data: \(importGroup.importDate)")
            let songRecords = await fetcher.songRecords(for: importGroup.id, playType: playTypeToShow)
            let computed = computeAllCounts(from: songRecords)
            let clearTypeData = computed.clearType
            let djLevelData = computed.djLevel

            if sumOfCounts(clearTypeData) > 0 {
                debugPrint("Adding: \(importGroup.importDate)")
                newClearTypeData[importGroup.importDate] = clearTypeData
            }
            if sumOfCounts(djLevelData) > 0 {
                newDJLevelData[importGroup.importDate] = djLevelData
            }
        }

        await MainActor.run {
            withAnimation(.snappy.speed(2.0)) {
                self.clearTypePerImportGroup = newClearTypeData
                self.djLevelPerImportGroup = newDJLevelData
            }
        }
    }

    // MARK: New Clears & High Scores
    // swiftlint:disable function_body_length
    func reloadNewClearsAndHighScores() async {
        debugPrint("Calculating new clears and high scores")
        var importGroups = await fetcher.allImportGroups()
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

        let latestRecords = await fetcher.songRecords(
            for: latestGroup.id, playType: playTypeToShow
        ).sorted(by: {
            $0.lastPlayDate < $1.lastPlayDate
        })
        let previousRecords = await fetcher.songRecords(for: previousGroup.id, playType: playTypeToShow)

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
