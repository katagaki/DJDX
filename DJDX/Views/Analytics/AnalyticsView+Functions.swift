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
            async let overviewTask: () = reloadOverview()
            async let trendsTask: () = reloadTrends()
            async let newClearsTask: () = reloadNewClearsAndHighScores()
            _ = await (overviewTask, trendsTask, newClearsTask)
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
            let result = await fetcher.aggregatedCounts(
                for: [importGroupID], playType: playTypeToShow
            )
            let rawClearType = result.clearType[importGroupID]
            let rawDJLevel = result.djLevel[importGroupID]

            if let rawClearType, !rawClearType.isEmpty {
                let newClearType = buildOrderedClearType(from: rawClearType)
                let newDJLevel = buildOrderedDJLevel(from: rawDJLevel ?? [:])
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
        let importGroups = await fetcher.importGroups(for: iidxVersion)
        guard !importGroups.isEmpty else { return }

        let importGroupIDs = importGroups.map(\.id)
        let idToDate = Dictionary(uniqueKeysWithValues: importGroups.map { ($0.id, $0.importDate) })

        let result = await fetcher.aggregatedCounts(for: importGroupIDs, playType: playTypeToShow)

        var newClearTypeData: [Date: [Int: OrderedDictionary<String, Int>]] = [:]
        var newDJLevelData: [Date: [Int: OrderedDictionary<String, Int>]] = [:]

        for igID in importGroupIDs {
            guard let date = idToDate[igID] else { continue }

            if let rawClearType = result.clearType[igID] {
                let ordered = buildOrderedClearType(from: rawClearType)
                if sumOfCounts(ordered) > 0 {
                    newClearTypeData[date] = ordered
                }
            }
            if let rawDJLevel = result.djLevel[igID] {
                let ordered = buildOrderedDJLevel(from: rawDJLevel)
                if sumOfCounts(ordered) > 0 {
                    newDJLevelData[date] = ordered
                }
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
        let importGroups = await fetcher.importGroups(for: iidxVersion)

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

        async let latestRecordsTask = fetcher.songRecords(
            for: latestGroup.id, playType: playTypeToShow
        )
        async let previousRecordsTask = fetcher.songRecords(
            for: previousGroup.id, playType: playTypeToShow
        )

        let latestRecords = await latestRecordsTask.sorted(by: {
            $0.lastPlayDate < $1.lastPlayDate
        })
        let previousRecords = await previousRecordsTask

        // Build lookup by compact title for previous records
        var previousByTitle: [String: IIDXSongRecord] = [:]
        previousByTitle.reserveCapacity(previousRecords.count)
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
