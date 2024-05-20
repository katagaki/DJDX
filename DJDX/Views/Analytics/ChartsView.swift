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

    @AppStorage(wrappedValue: 1, "SelectedLevelFilterForScoreRateInAnalyticsView") var levelFilterForScoreRate: Int

    @State var isInitialScoresLoaded: Bool = false
    @State var clearLampPerDifficulty: [Int: [String: Int]] = [:] // [Difficulty: [Clear Type: Count]]
    @State var scoresPerDifficulty: [Int: [String: Int]] = [:] // [Difficulty: [DJ Level: Count]]
    let djLevels: [String] = ["F", "E", "D", "C", "B", "A", "AA", "AAA"]

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
                    .chartXScale(domain: 1...12)
                    .chartForegroundStyleScale([
                        "FULLCOMBO CLEAR": .white,
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
                    ListSectionHeader(text: "クリアランプ")
                        .font(.body)
                }
                Section {
                    Picker(selection: $levelFilterForScoreRate.animation()) {
                        Text("LEVEL 1").tag(1)
                        Text("LEVEL 2").tag(2)
                        Text("LEVEL 3").tag(3)
                        Text("LEVEL 4").tag(4)
                        Text("LEVEL 5").tag(5)
                        Text("LEVEL 6").tag(6)
                        Text("LEVEL 7").tag(7)
                        Text("LEVEL 8").tag(8)
                        Text("LEVEL 9").tag(9)
                        Text("LEVEL 10").tag(10)
                        Text("LEVEL 11").tag(11)
                        Text("LEVEL 12").tag(12)
                    } label: {
                        Text("レベル")
                    }
                    Chart(scoresPerDifficulty[levelFilterForScoreRate]?.sorted(by: <) ??
                          [:].sorted(by: <), id: \.key) { djLevel, count in
                        BarMark(
                            x: .value("DJ LEVEL", djLevel),
                            y: .value("CLEAR COUNT", count),
                            width: .fixed(10.0)
                        )
                    }
                    .chartLegend(.visible)
                    .chartXScale(domain: djLevels)
                    .frame(height: 200.0)
                    .listRowInsets(.init(top: 18.0, leading: 18.0, bottom: 18.0, trailing: 18.0))
                } header: {
                    ListSectionHeader(text: "スコアレート")
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
        withAnimation {
            clearLampPerDifficulty.removeAll()
            scoresPerDifficulty.removeAll()
        }
        Task.detached {
            let songRecords = await songRecords

            var newClearLampPerDifficulty: [Int: [String: Int]] = [:]
            var newScoresPerDifficulty: [Int: [String: Int]] = [:]
            for difficulty in 1...12 {
                newScoresPerDifficulty[difficulty] = ["F": 0, "E": 0, "D": 0, "C": 0, "B": 0, "A": 0, "AA": 0, "AAA": 0]
                newClearLampPerDifficulty[difficulty] = [
                    "FULLCOMBO CLEAR": 0,
                    "CLEAR": 0,
                    "ASSIST CLEAR": 0,
                    "EASY CLEAR": 0,
                    "HARD CLEAR": 0,
                    "EX HARD CLEAR": 0,
                    "FAILED": 0
                ]
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
                withAnimation {
                    self.clearLampPerDifficulty = newClearLampPerDifficulty
                    self.scoresPerDifficulty = newScoresPerDifficulty
                }
            }
        }
    }
}
