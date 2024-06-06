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
    @State var scoreRatePerDifficulty: [Int: [IIDXDJLevel: Int]] = [:] // [Difficulty: [DJ Level: Count]]

    @State var dataState: DataState = .initializing

    let difficulties: [Int] = Array(1...12)

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
                        if clearLampPerDifficulty.count > 0 {
                            NavigationLink(value: ViewPath.clearLampOverviewGraph) {
                                Image(systemName: "square.arrowtriangle.4.outward")
                            }
                        }
                    }
                }
                Section {
                    ClearLampPerDifficultyGraph(clearLampPerDifficulty: $clearLampPerDifficulty,
                                                selectedDifficulty: $levelFilterForClearLamp)
                    .frame(height: 156.0)
                    .listRowInsets(.init(top: 18.0, leading: 20.0, bottom: 18.0, trailing: 20.0))
                    DifficultyPicker(selection: $levelFilterForClearLamp,
                                     difficulties: .constant(difficulties))
                } header: {
                    HStack(spacing: 8.0) {
                        ListSectionHeader(text: "Analytics.ClearLamp.ByDifficulty")
                            .font(.body)
                        Spacer()
                        if clearLampPerDifficulty.count > 0 {
                            NavigationLink(value: ViewPath.clearLampPerDifficultyGraph) {
                                Image(systemName: "square.arrowtriangle.4.outward")
                            }
                        }
                    }
                }
                Section {
                    DJLevelPerDifficultyGraph(djLevelPerDifficulty: $scoreRatePerDifficulty,
                                                selectedDifficulty: $levelFilterForScoreRate)
                    .frame(height: 156.0)
                    .listRowInsets(.init(top: 18.0, leading: 20.0, bottom: 18.0, trailing: 20.0))
                    DifficultyPicker(selection: $levelFilterForScoreRate,
                                     difficulties: .constant(difficulties))
                } header: {
                    HStack(spacing: 8.0) {
                        ListSectionHeader(text: "Analytics.DJLevel.ByDifficulty")
                            .font(.body)
                        Spacer()
                        if scoreRatePerDifficulty.count > 0 {
                            NavigationLink(value: ViewPath.scoreRatePerDifficultyGraph) {
                                Image(systemName: "square.arrowtriangle.4.outward")
                            }
                        }
                    }
                }
            }
            .navigationTitle("ViewTitle.Analytics")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    switch dataState {
                    case .initializing, .loading:
                        ProgressView()
                            .progressViewStyle(.circular)
                    case .presenting:
                        Color.clear
                    }
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
            .navigationDestination(for: ViewPath.self) { viewPath in
                Group {
                    switch viewPath {
                    case .clearLampOverviewGraph:
                        ClearLampOverviewGraph(clearLampPerDifficulty: $clearLampPerDifficulty,
                                               isInteractive: true)
                        .navigationTitle("Analytics.ClearLamp.Overall")
                    case .clearLampPerDifficultyGraph:
                        ClearLampPerDifficultyGraph(clearLampPerDifficulty: $clearLampPerDifficulty,
                                                    selectedDifficulty: $levelFilterForClearLamp,
                                                    legendPosition: .bottom)
                        .navigationTitle("Analytics.ClearLamp.ByDifficulty")
                    case .scoreRatePerDifficultyGraph:
                        DJLevelPerDifficultyGraph(djLevelPerDifficulty: $scoreRatePerDifficulty,
                                                    selectedDifficulty: $levelFilterForScoreRate)
                        .navigationTitle("Analytics.DJLevel.ByDifficulty")
                    default: Color.clear
                    }
                }
                .padding()
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
