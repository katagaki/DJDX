//
//  AnalyticsView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import Charts
import Komponents
import OrderedCollections
import SwiftData
import SwiftUI

struct AnalyticsView: View {

    @Environment(\.modelContext) var modelContext

    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var calendar: CalendarManager

    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var playTypeToShow: IIDXPlayType
    @AppStorage(wrappedValue: 1, "SelectedLevelFilterForClearLampInAnalyticsView") var levelFilterForClearLamp: Int
    @AppStorage(wrappedValue: 1, "SelectedLevelFilterForScoreRateInAnalyticsView") var levelFilterForScoreRate: Int

    // Overall
    @State var clearLampPerDifficulty: [Int: OrderedDictionary<String, Int>] = [:] // [Difficulty: [Clear Type: Count]]
    @State var scoreRatePerDifficulty: [Int: [IIDXDJLevel: Int]] = [:] // [Difficulty: [DJ Level: Count]]

    // Trends
//    @State var clearLamp

    @State var dataState: DataState = .initializing
    @State var viewMode: AnalyticsViewMode = .overall

    let difficulties: [Int] = Array(1...12)

    var body: some View {
        NavigationStack(path: $navigationManager[.analytics]) {
            List {
                switch viewMode {
                case .overall:
                    Section {
                        OverviewClearLampOverallGraph(clearLampPerDifficulty: $clearLampPerDifficulty)
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
                        OverviewClearLampPerDifficultyGraph(clearLampPerDifficulty: $clearLampPerDifficulty,
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
                        OverviewDJLevelPerDifficultyGraph(djLevelPerDifficulty: $scoreRatePerDifficulty,
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
                case .trends:
                    ContentUnavailableView("Shared.NotImplemented", systemImage: "questionmark.app.dashed")
                }
            }
            .navigationTitle("ViewTitle.Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Spacer()
                }
                ToolbarItem(placement: .topBarLeading) {
                    LargeInlineTitle("ViewTitle.Analytics")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if dataState == .initializing || dataState == .loading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0.0) {
                ScrollView(.horizontal) {
                    HStack(spacing: 8.0) {
                        PlayTypePicker(playTypeToShow: $playTypeToShow)
                        ToolbarButton("Analytics.Overall", icon: "chart.pie",
                                      isSecondary: viewMode != .overall) {
                            withAnimation(.snappy.speed(2.0)) {
                                viewMode = .overall
                            }
                        }
                        ToolbarButton("Analytics.Trend", icon: "chart.line.uptrend.xyaxis",
                                      isSecondary: viewMode != .trends) {
                            withAnimation(.snappy.speed(2.0)) {
                                viewMode = .trends
                            }
                        }
                    }
                    .padding([.leading, .trailing], 16.0)
                    .padding([.top, .bottom], 12.0)
                }
                .scrollIndicators(.hidden)
                .background(Material.bar)
                .overlay(alignment: .top) {
                    Rectangle()
                        .frame(height: 1/3)
                        .foregroundColor(.primary.opacity(0.2))
                        .ignoresSafeArea(edges: [.leading, .trailing])
                }
            }
            .task {
                if dataState == .initializing {
                    reloadScores()
                }
            }
            .onChange(of: calendar.didUserPerformChangesRequiringDisplayDataReload, { oldValue, newValue in
                if !oldValue && newValue {
                    calendar.didUserPerformChangesRequiringDisplayDataReload = false
                    dataState = .initializing
                }
            })
            .onChange(of: calendar.selectedDate) { oldValue, newValue in
                if !Calendar.current.isDate(oldValue, inSameDayAs: newValue) {
                    dataState = .initializing
                }
            }
            .onChange(of: playTypeToShow) { _, _ in
                if navigationManager.selectedTab == .analytics {
                    reloadScores()
                } else {
                    dataState = .initializing
                }
            }
            .navigationDestination(for: ViewPath.self) { viewPath in
                Group {
                    switch viewPath {
                    case .clearLampOverviewGraph:
                        OverviewClearLampOverallGraph(clearLampPerDifficulty: $clearLampPerDifficulty,
                                               isInteractive: true)
                        .navigationTitle("Analytics.ClearLamp.Overall")
                    case .clearLampPerDifficultyGraph:
                        OverviewClearLampPerDifficultyGraph(clearLampPerDifficulty: $clearLampPerDifficulty,
                                                    selectedDifficulty: $levelFilterForClearLamp,
                                                    legendPosition: .bottom)
                        .navigationTitle("Analytics.ClearLamp.ByDifficulty")
                    case .scoreRatePerDifficultyGraph:
                        OverviewDJLevelPerDifficultyGraph(djLevelPerDifficulty: $scoreRatePerDifficulty,
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
