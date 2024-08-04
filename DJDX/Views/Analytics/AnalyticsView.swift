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
    @AppStorage(wrappedValue: 1, "Analytics.Overview.ClearType.Level") var levelFilterForOverviewClearType: Int
    @AppStorage(wrappedValue: 1, "Analytics.Overview.ScoreRate.Level") var levelFilterForOverviewScoreRate: Int
    @AppStorage(wrappedValue: 1, "Analytics.Trends.ClearType.Level") var levelFilterForTrendsClearType: Int
    @AppStorage(wrappedValue: 1, "Analytics.Trends.DJLevel.Level") var levelFilterForTrendsDJLevel: Int

    // Overall

    @State var clearTypePerDifficulty: [Int: OrderedDictionary<String, Int>] = [:]
    // [Difficulty: [Clear Type: Count]]

    @State var djLevelPerDifficulty: [Int: [IIDXDJLevel: Int]] = [:]
    // [Difficulty: [DJ Level: Count]]

    // Trends

    @State var clearTypePerImportGroup: [Date: [Int: OrderedDictionary<String, Int>]] = [:]
    // [Import Group Date: [Difficulty: [Clear Type: Count]]]
    @AppStorage(wrappedValue: Data(), "Analytics.Trends.ClearType.Level.Cache") var clearTypePerImportGroupCache: Data

    @State var djLevelPerImportGroup: [Date: [Int: OrderedDictionary<String, Int>]] = [:]
    // [Import Group Date: [DJ Level: Count]]
    @AppStorage(wrappedValue: Data(), "Analytics.Trends.DJLevel.Level.Cache") var djLevelPerImportGroupCache: Data

    @State var dataState: DataState = .initializing
    @AppStorage(wrappedValue: .overview, "Analytics.ViewMode") var viewMode: AnalyticsViewMode

    let difficulties: [Int] = Array(1...12)

    var body: some View {
        NavigationStack(path: $navigationManager[.analytics]) {
            List {
                switch viewMode {
                case .overview:
                    Section {
                        OverviewClearTypeOverallGraph(graphData: $clearTypePerDifficulty)
                        .frame(height: 200.0)
                        .listRowInsets(.init(top: 18.0, leading: 20.0, bottom: 18.0, trailing: 20.0))
                    } header: {
                        HStack(spacing: 8.0) {
                            ListSectionHeader(text: "Analytics.ClearType.Overall")
                                .font(.body)
                            Spacer()
                            if clearTypePerDifficulty.count > 0 {
                                NavigationLink(value: ViewPath.clearTypeOverviewGraph) {
                                    Image(systemName: "square.arrowtriangle.4.outward")
                                }
                            }
                        }
                    }
                    Section {
                        OverviewClearTypePerDifficultyGraph(graphData: $clearTypePerDifficulty,
                                                            difficulty: $levelFilterForOverviewClearType)
                        .frame(height: 156.0)
                        .listRowInsets(.init(top: 18.0, leading: 20.0, bottom: 18.0, trailing: 20.0))
                        DifficultyPicker(selection: $levelFilterForOverviewClearType,
                                         difficulties: .constant(difficulties))
                    } header: {
                        HStack(spacing: 8.0) {
                            ListSectionHeader(text: "Analytics.ClearType.ByDifficulty")
                                .font(.body)
                            Spacer()
                            if clearTypePerDifficulty.count > 0 {
                                NavigationLink(value: ViewPath.clearTypePerDifficultyGraph) {
                                    Image(systemName: "square.arrowtriangle.4.outward")
                                }
                            }
                        }
                    }
                    Section {
                        OverviewDJLevelPerDifficultyGraph(graphData: $djLevelPerDifficulty,
                                                          difficulty: $levelFilterForOverviewScoreRate)
                        .frame(height: 156.0)
                        .listRowInsets(.init(top: 18.0, leading: 20.0, bottom: 18.0, trailing: 20.0))
                        DifficultyPicker(selection: $levelFilterForOverviewScoreRate,
                                         difficulties: .constant(difficulties))
                    } header: {
                        HStack(spacing: 8.0) {
                            ListSectionHeader(text: "Analytics.DJLevel.ByDifficulty")
                                .font(.body)
                            Spacer()
                            if djLevelPerDifficulty.count > 0 {
                                NavigationLink(value: ViewPath.scoreRatePerDifficultyGraph) {
                                    Image(systemName: "square.arrowtriangle.4.outward")
                                }
                            }
                        }
                    }
                case .trends:
                    Section {
                        TrendsClearTypeGraph(graphData: $clearTypePerImportGroup,
                                             difficulty: $levelFilterForTrendsClearType)
                        .frame(height: 256.0)
                        .listRowInsets(.init(top: 18.0, leading: 20.0, bottom: 18.0, trailing: 20.0))
                        DifficultyPicker(selection: $levelFilterForTrendsClearType,
                                         difficulties: .constant(difficulties))
                    } header: {
                        HStack(spacing: 8.0) {
                            ListSectionHeader(text: "Analytics.Trends.ClearType")
                                .font(.body)
                            Spacer()
                            if clearTypePerImportGroup.count > 0 {
                                NavigationLink(value: ViewPath.trendsClearTypeGraph) {
                                    Image(systemName: "square.arrowtriangle.4.outward")
                                }
                            }
                        }
                    }
                    Section {
                        TrendsDJLevelGraph(graphData: $djLevelPerImportGroup,
                                           difficulty: $levelFilterForTrendsDJLevel)
                        .frame(height: 256.0)
                        .listRowInsets(.init(top: 18.0, leading: 20.0, bottom: 18.0, trailing: 20.0))
                        DifficultyPicker(selection: $levelFilterForTrendsDJLevel,
                                         difficulties: .constant(difficulties))
                    } header: {
                        HStack(spacing: 8.0) {
                            ListSectionHeader(text: "Analytics.Trends.DJLevel")
                                .font(.body)
                            Spacer()
                            if clearTypePerImportGroup.count > 0 {
                                NavigationLink(value: ViewPath.trendsDJLevelGraph) {
                                    Image(systemName: "square.arrowtriangle.4.outward")
                                }
                            }
                        }
                    }
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
                        .onTapGesture(count: 5) {
                            debugPrint("Clearing cache")
                            clearTypePerImportGroupCache = Data()
                            djLevelPerImportGroupCache = Data()
                            reload()
                        }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if dataState == .initializing || dataState == .loading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0.0) {
                TabBarAccessory(placement: .bottom) {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8.0) {
                            PlayTypePicker(playTypeToShow: $playTypeToShow)
                            ToolbarButton("Analytics.Overall", icon: "chart.pie",
                                          isSecondary: viewMode != .overview) {
                                withAnimation(.snappy.speed(2.0)) {
                                    viewMode = .overview
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
                }
            }
            .refreshable {
                switch viewMode {
                case .trends:
                    clearTypePerImportGroupCache = Data()
                    djLevelPerImportGroupCache = Data()
                default: break
                }
                reload()
            }
            .onAppear {
                if dataState == .initializing {
                    calendar.analyticsDate = .now
                    reload()
                }
            }
            .onChange(of: calendar.shouldReloadDisplayedData, { oldValue, newValue in
                if !oldValue && newValue {
                    calendar.shouldReloadDisplayedData = false
                    dataState = .initializing
                }
            })
            .onChange(of: calendar.analyticsDate) { oldValue, newValue in
                if !Calendar.current.isDate(oldValue, inSameDayAs: newValue) {
                    dataState = .initializing
                }
            }
            .onChange(of: viewMode) { _, newValue in
                var shouldReload: Bool = false
                switch newValue {
                case .overview: shouldReload = clearTypePerDifficulty.count == 0 || djLevelPerDifficulty.count == 0
                case .trends: shouldReload = clearTypePerImportGroup.count == 0 || djLevelPerImportGroup.count == 0
                }
                if shouldReload {
                    reload()
                }
            }
            .onChange(of: playTypeToShow) { _, _ in
                if navigationManager.selectedTab == .analytics {
                    reload()
                } else {
                    dataState = .initializing
                }
            }
            .navigationDestination(for: ViewPath.self) { viewPath in
                Group {
                    switch viewPath {
                    case .clearTypeOverviewGraph:
                        OverviewClearTypeOverallGraph(graphData: $clearTypePerDifficulty,
                                                      isInteractive: true)
                        .navigationTitle("Analytics.ClearType.Overall")
                    case .clearTypePerDifficultyGraph:
                        OverviewClearTypePerDifficultyGraph(graphData: $clearTypePerDifficulty,
                                                            difficulty: $levelFilterForOverviewClearType,
                                                            legendPosition: .bottom)
                        .navigationTitle("Analytics.ClearType.ByDifficulty")
                    case .scoreRatePerDifficultyGraph:
                        OverviewDJLevelPerDifficultyGraph(graphData: $djLevelPerDifficulty,
                                                          difficulty: $levelFilterForOverviewScoreRate)
                        .navigationTitle("Analytics.DJLevel.ByDifficulty")
                    case .trendsClearTypeGraph:
                        TrendsClearTypeGraph(graphData: $clearTypePerImportGroup,
                                             difficulty: $levelFilterForTrendsClearType)
                        .navigationTitle("Analytics.Trends.ClearType")
                    case .trendsDJLevelGraph:
                        TrendsDJLevelGraph(graphData: $djLevelPerImportGroup,
                                           difficulty: $levelFilterForTrendsDJLevel)
                        .navigationTitle("Analytics.Trends.DJLevel")
                    default: Color.clear
                    }
                }
                .padding()
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
