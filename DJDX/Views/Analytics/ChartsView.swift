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
                    Chart(Array(clearLampPerDifficulty.keys), id: \.self) { difficulty in
                        ForEach(clearLampPerDifficulty[difficulty]!.sorted(by: <), id: \.key) { clearType, count in
                            BarMark(
                                x: .value("LEVEL", difficulty),
                                y: .value("CLEAR COUNT", count),
                                width: .fixed(10.0)
                            )
                            .foregroundStyle(
                                by: .value("CLEAR TYPE", clearType)
                            )
                            .position(
                                by: .value("CLEAR TYPE", clearType),
                                axis: .horizontal,
                                span: .ratio(1)
                            )
                        }
                    }
                    .chartLegend(.visible)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 13))
                    }
                    .chartXScale(domain: 1...13)
                    .chartForegroundStyleScale([
                        "FULLCOMBO CLEAR": .blue,
                        "CLEAR": .cyan,
                        "ASSIST CLEAR": .purple,
                        "EASY CLEAR": .green,
                        "HARD CLEAR": .pink,
                        "EX HARD CLEAR": .yellow,
                        "FAILED": .red
                    ])
                    .frame(height: 200.0)
                    .listRowInsets(.init(top: 18.0, leading: 18.0, bottom: 18.0, trailing: 18.0))
                } header: {
                    ListSectionHeader(text: "クリアランプ（全体）")
                        .font(.body)
                }
                Section {
                    Picker(selection: $levelFilterForClearLamp.animation(.snappy.speed(2.0))) {
                        ForEach(difficulties, id: \.self) { difficulty in
                            Text("LEVEL \(difficulty)").tag(difficulty)
                        }
                    } label: {
                        Text("レベル")
                    }
                    Chart(clearLampPerDifficulty[levelFilterForClearLamp]?.sorted(by: <) ??
                          [:].sorted(by: <), id: \.key) { clearType, count in
                        SectorMark(angle: .value(clearType, count))
                            .foregroundStyle(
                                by: .value("CLEAR TYPE", clearType)
                            )
                    }
                    .chartLegend(.visible)
                    .chartXScale(domain: clearTypes)
                    .chartForegroundStyleScale([
                      "FULLCOMBO CLEAR": .blue,
                      "CLEAR": .cyan,
                      "ASSIST CLEAR": .purple,
                      "EASY CLEAR": .green,
                      "HARD CLEAR": .pink,
                      "EX HARD CLEAR": .yellow,
                      "FAILED": .red
                    ])
                    .frame(height: 158.0)
                    .listRowInsets(.init(top: 18.0, leading: 18.0, bottom: 18.0, trailing: 18.0))
                } header: {
                    ListSectionHeader(text: "クリアランプ（レベル別）")
                        .font(.body)
                }
                Section {
                    Picker(selection: $levelFilterForScoreRate.animation(.snappy.speed(2.0))) {
                        ForEach(difficulties, id: \.self) { difficulty in
                            Text("LEVEL \(difficulty)").tag(difficulty)
                        }
                    } label: {
                        Text("レベル")
                    }
                    Chart(scoreRatePerDifficulty[levelFilterForScoreRate]?.sorted(by: <) ??
                          [:].sorted(by: <), id: \.key) { djLevel, count in
                        BarMark(
                            x: .value("DJ LEVEL", djLevel),
                            y: .value("CLEAR COUNT", count),
                            width: .fixed(10.0)
                        )
                    }
                    .chartLegend(.visible)
                    .chartXScale(domain: djLevels)
                    .frame(height: 158.0)
                    .listRowInsets(.init(top: 18.0, leading: 18.0, bottom: 18.0, trailing: 18.0))
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
