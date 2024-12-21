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

    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var playTypeToShow: IIDXPlayType
    @AppStorage(wrappedValue: 1, "Analytics.Overview.ClearType.Level") var levelFilterForOverviewClearType: Int
    @AppStorage(wrappedValue: 1, "Analytics.Overview.ScoreRate.Level") var levelFilterForOverviewScoreRate: Int
    @AppStorage(wrappedValue: 1, "Analytics.Trends.ClearType.Level") var levelFilterForTrendsClearType: Int
    @AppStorage(wrappedValue: 1, "Analytics.Trends.DJLevel.Level") var levelFilterForTrendsDJLevel: Int
    @AppStorage(wrappedValue: IIDXVersion.pinkyCrush, "Global.IIDX.Version") var iidxVersion: IIDXVersion

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

    @Namespace var analyticsNamespace

    var body: some View {
        NavigationStack(path: $navigationManager[.analytics]) {
            List {
                switch viewMode {
                case .overview:
                    Section {
                        OverviewClearTypeOverallGraph(graphData: $clearTypePerDifficulty)
                        .frame(height: 200.0)
                        .automaticMatchedTransitionSource(id: "ClearType.Overall", in: analyticsNamespace)
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
                    // This graph causes a crash when the data is empty
                    Section {
                        OverviewClearTypePerDifficultyGraph(graphData: $clearTypePerDifficulty,
                                                            difficulty: $levelFilterForOverviewClearType)
                        .frame(height: 156.0)
                        .automaticMatchedTransitionSource(id: "ClearType.ByDifficulty", in: analyticsNamespace)
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
                        .automaticMatchedTransitionSource(id: "DJLevel.ByDifficulty", in: analyticsNamespace)
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
                        .automaticMatchedTransitionSource(id: "Trends.ClearType", in: analyticsNamespace)
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
                        .automaticMatchedTransitionSource(id: "Trends.DJLevel", in: analyticsNamespace)
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
            .navigator("ViewTitle.Analytics", group: true)
            .listSectionSpacing(.compact)
            .toolbarBackground(.hidden, for: .tabBar)
            .toolbar {
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
                await reload()
                debugPrint("Reloaded from swipe to refresh")
            }
            .task {
                if dataState == .initializing {
                    await reload()
                }
            }
            .onChange(of: viewMode) { _, newValue in
                var shouldReload: Bool = false
                switch newValue {
                case .overview: shouldReload = clearTypePerDifficulty.count == 0 || djLevelPerDifficulty.count == 0
                case .trends: shouldReload = clearTypePerImportGroup.count == 0 || djLevelPerImportGroup.count == 0
                }
                if shouldReload {
                    Task {
                        await reload()
                        debugPrint("Reloaded on change of view mode")
                    }
                }
            }
            .onChange(of: playTypeToShow) { _, _ in
                if navigationManager.selectedTab == .analytics {
                    Task {
                        await reload()
                        debugPrint("Reloaded on change of play type")
                    }
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
                        .automaticNavigationTransition(id: "ClearType.Overall", in: analyticsNamespace)
                    case .clearTypePerDifficultyGraph:
                        OverviewClearTypePerDifficultyGraph(graphData: $clearTypePerDifficulty,
                                                            difficulty: $levelFilterForOverviewClearType,
                                                            legendPosition: .bottom)
                        .navigationTitle("Analytics.ClearType.ByDifficulty")
                        .automaticNavigationTransition(id: "ClearType.ByDifficulty", in: analyticsNamespace)
                    case .scoreRatePerDifficultyGraph:
                        OverviewDJLevelPerDifficultyGraph(graphData: $djLevelPerDifficulty,
                                                          difficulty: $levelFilterForOverviewScoreRate)
                        .navigationTitle("Analytics.DJLevel.ByDifficulty")
                        .automaticNavigationTransition(id: "DJLevel.ByDifficulty", in: analyticsNamespace)
                    case .trendsClearTypeGraph:
                        TrendsClearTypeGraph(graphData: $clearTypePerImportGroup,
                                             difficulty: $levelFilterForTrendsClearType)
                        .navigationTitle("Analytics.Trends.ClearType")
                        .automaticNavigationTransition(id: "Trends.ClearType", in: analyticsNamespace)
                    case .trendsDJLevelGraph:
                        TrendsDJLevelGraph(graphData: $djLevelPerImportGroup,
                                           difficulty: $levelFilterForTrendsDJLevel)
                        .navigationTitle("Analytics.Trends.DJLevel")
                        .automaticNavigationTransition(id: "Trends.DJLevel", in: analyticsNamespace)
                    default: Color.clear
                    }
                }
                .padding()
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
