//
//  ChartsView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import Charts
import Komponents
import SwiftData
import SwiftUI

struct ChartsView: View {

    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(\.modelContext) var modelContext
    @Query var songRecords: [EPOLISSongRecord]

    @AppStorage(wrappedValue: 1, "SelectedLevelFilterForClearLampInAnalyticsView") var levelFilterForClearLamp: Int
    @AppStorage(wrappedValue: 1, "SelectedLevelFilterForScoreRateInAnalyticsView") var levelFilterForScoreRate: Int

    @State var isInitialScoresLoaded: Bool = false
    @State var clearLampPerDifficulty: [Int: [String: Int]] = [:] // [Difficulty: [Clear Type: Count]]
    @State var scoreRatePerDifficulty: [Int: [String: Int]] = [:] // [Difficulty: [DJ Level: Count]]

    let difficulties: [Int] = Array(1...12)
    let djLevels: [String] = ["F", "E", "D", "C", "B", "A", "AA", "AAA"]
    let clearTypes: [String] = [
        "FULLCOMBO CLEAR",
        "CLEAR",
        "ASSIST CLEAR",
        "EASY CLEAR",
        "HARD CLEAR",
        "EX HARD CLEAR",
        "FAILED"
    ]

    var body: some View {
        NavigationStack(path: $navigationManager.analyticsTabPath) {
            List {
                Section {
                    ClearLampOverviewChart(clearLampPerDifficulty: $clearLampPerDifficulty)
                    .frame(height: 200.0)
                    .listRowInsets(.init(top: 18.0, leading: 20.0, bottom: 18.0, trailing: 20.0))
                } header: {
                    ListSectionHeader(text: "クリアランプ（全体）")
                        .font(.body)
                }
                Section {
                    DifficultyPicker(selection: $levelFilterForClearLamp,
                                     difficulties: .constant(difficulties))
                    ClearLampPerDifficultyChart(clearLampPerDifficulty: $clearLampPerDifficulty,
                                                clearTypes: .constant(clearTypes),
                                                selectedDifficulty: $levelFilterForClearLamp)
                    .frame(height: 158.0)
                    .listRowInsets(.init(top: 18.0, leading: 20.0, bottom: 18.0, trailing: 20.0))
                } header: {
                    ListSectionHeader(text: "クリアランプ（レベル別）")
                        .font(.body)
                }
                Section {
                    DifficultyPicker(selection: $levelFilterForScoreRate,
                                     difficulties: .constant(difficulties))
                    ScoreRatePerDifficultyChart(scoreRatePerDifficulty: $scoreRatePerDifficulty,
                                                djLevels: .constant(djLevels),
                                                selectedDifficulty: $levelFilterForScoreRate)
                    .frame(height: 158.0)
                    .listRowInsets(.init(top: 18.0, leading: 20.0, bottom: 18.0, trailing: 20.0))
                } header: {
                    ListSectionHeader(text: "スコアレート（レベル別）")
                        .font(.body)
                }
            }
            .navigationTitle("プレー分析")
            .refreshable {
                withAnimation {
                    reloadScores()
                }
            }
            .task {
                if !isInitialScoresLoaded {
                    isInitialScoresLoaded = true
                    withAnimation {
                        reloadScores()
                    }
                }
            }
        }
    }

    func reloadScores() {
        withAnimation(.snappy.speed(2.0)) {
            clearLampPerDifficulty.removeAll()
            scoreRatePerDifficulty.removeAll()
        }
        Task.detached {
            let songRecords = await songRecords

            var newClearLampPerDifficulty: [Int: [String: Int]] = [:]
            var newScoresPerDifficulty: [Int: [String: Int]] = [:]
            for difficulty in difficulties {
                newScoresPerDifficulty[difficulty] = djLevels.reduce(into: [String: Int]()) { $0[$1] = 0 }
                newClearLampPerDifficulty[difficulty] = clearTypes.reduce(into: [String: Int]()) { $0[$1] = 0 }
            }

            var scores: [ScoreForLevel] = []
            for songRecord in songRecords {
                let scoresAvailable: [ScoreForLevel] = [
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
                if score.djLevel != "---" {
                    newScoresPerDifficulty[score.difficulty]?[score.djLevel]? += 1
                }
                if score.clearType != "NO PLAY" {
                    newClearLampPerDifficulty[score.difficulty]?[score.clearType]? += 1
                }
            }

            await MainActor.run { [newClearLampPerDifficulty, newScoresPerDifficulty] in
                withAnimation(.snappy.speed(2.0)) {
                    self.clearLampPerDifficulty = newClearLampPerDifficulty
                    self.scoreRatePerDifficulty = newScoresPerDifficulty
                }
            }
        }
    }
}
