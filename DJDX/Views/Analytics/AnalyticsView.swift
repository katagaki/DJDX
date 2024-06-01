//
//  AnalyticsView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import Charts
import Komponents
import SwiftData
import SwiftUI

struct AnalyticsView: View {

    @Environment(\.modelContext) var modelContext

    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var calendar: CalendarManager

    @AppStorage(wrappedValue: 1, "SelectedLevelFilterForClearLampInAnalyticsView") var levelFilterForClearLamp: Int
    @AppStorage(wrappedValue: 1, "SelectedLevelFilterForScoreRateInAnalyticsView") var levelFilterForScoreRate: Int

    @State var clearLampPerDifficulty: [Int: [String: Int]] = [:] // [Difficulty: [Clear Type: Count]]
    @State var scoreRatePerDifficulty: [Int: [String: Int]] = [:] // [Difficulty: [DJ Level: Count]]

    @State var dataState: DataState = .initializing

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
        NavigationStack(path: $navigationManager[.analytics]) {
            List {
                Section {
                    ClearLampOverviewGraph(clearLampPerDifficulty: $clearLampPerDifficulty)
                    .frame(height: 200.0)
                    .listRowInsets(.init(top: 18.0, leading: 20.0, bottom: 18.0, trailing: 20.0))
                } header: {
                    HStack(spacing: 8.0) {
                        ListSectionHeader(text: "Analytics.ClearLamp.Overall")
                            .font(.body)
                        Spacer()
                        NavigationLink {
                            ClearLampOverviewGraph(clearLampPerDifficulty: $clearLampPerDifficulty,
                                                   isInteractive: true)
                                .padding()
                                .navigationTitle("Analytics.ClearLamp.Overall")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            Image(systemName: "square.arrowtriangle.4.outward")
                        }
                    }
                }
                Section {
                    ClearLampPerDifficultyGraph(clearLampPerDifficulty: $clearLampPerDifficulty,
                                                clearTypes: .constant(clearTypes),
                                                selectedDifficulty: $levelFilterForClearLamp)
                    .frame(height: 156.0)
                    .listRowInsets(.init(top: 18.0, leading: 20.0, bottom: 18.0, trailing: 20.0))
                    DifficultyPicker(selection: $levelFilterForClearLamp,
                                     difficulties: .constant(difficulties))
                } header: {
                    HStack(spacing: 8.0) {
                        ListSectionHeader(text: "Analytics.ClearLamp.ByLevel")
                            .font(.body)
                        Spacer()
                        NavigationLink {
                            ClearLampPerDifficultyGraph(clearLampPerDifficulty: $clearLampPerDifficulty,
                                                        clearTypes: .constant(clearTypes),
                                                        selectedDifficulty: $levelFilterForClearLamp,
                                                        legendPosition: .bottom)
                            .padding()
                            .navigationTitle("Analytics.ClearLamp.ByLevel")
                            .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            Image(systemName: "square.arrowtriangle.4.outward")
                        }
                    }
                }
                Section {
                    ScoreRatePerDifficultyGraph(scoreRatePerDifficulty: $scoreRatePerDifficulty,
                                                djLevels: .constant(djLevels),
                                                selectedDifficulty: $levelFilterForScoreRate)
                    .frame(height: 156.0)
                    .listRowInsets(.init(top: 18.0, leading: 20.0, bottom: 18.0, trailing: 20.0))
                    DifficultyPicker(selection: $levelFilterForScoreRate,
                                     difficulties: .constant(difficulties))
                } header: {
                    HStack(spacing: 8.0) {
                        ListSectionHeader(text: "Analytics.ScoreRate.ByLevel")
                            .font(.body)
                        Spacer()
                        NavigationLink {
                            ScoreRatePerDifficultyGraph(scoreRatePerDifficulty: $scoreRatePerDifficulty,
                                                        djLevels: .constant(djLevels),
                                                        selectedDifficulty: $levelFilterForScoreRate)
                            .padding()
                            .navigationTitle("Analytics.ScoreRate.ByLevel")
                            .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            Image(systemName: "square.arrowtriangle.4.outward")
                        }
                    }
                }
            }
            .navigationTitle("ViewTitle.Analytics")
            .refreshable {
                withAnimation(.snappy.speed(2.0)) {
                    reloadScores()
                }
            }
            .task {
                if dataState == .initializing {
                    reloadScores()
                }
            }
            .onChange(of: calendar.selectedDate) { oldValue, newValue in
                if !Calendar.current.isDate(oldValue, inSameDayAs: newValue) {
                    dataState = .initializing
                }
            }
        }
    }

    func reloadScores() {
        dataState = .loading
        let songRecords = ScoresView.latestAvailableIIDXSongRecords(in: modelContext, using: calendar)
        var newClearLampPerDifficulty: [Int: [String: Int]] = [:]
        var newScoresPerDifficulty: [Int: [String: Int]] = [:]
        for difficulty in difficulties {
            newScoresPerDifficulty[difficulty] = djLevels.reduce(into: [String: Int]()) { $0[$1] = 0 }
            newClearLampPerDifficulty[difficulty] = clearTypes.reduce(into: [String: Int]()) { $0[$1] = 0 }
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
            if score.djLevel != "---" {
                newScoresPerDifficulty[score.difficulty]?[score.djLevel]? += 1
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
