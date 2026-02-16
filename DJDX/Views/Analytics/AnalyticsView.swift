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
    @AppStorage(wrappedValue: IIDXVersion.sparkleShower, "Global.IIDX.Version") var iidxVersion: IIDXVersion

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

    let difficulties: [Int] = Array(1...12)

    @Namespace var analyticsNamespace

    var body: some View {
        NavigationStack(path: $navigationManager[.analytics]) {
            List {
                // Overview
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
                // Trends
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
            .navigator("ViewTitle.Analytics", group: true)
            .listSectionSpacing(.compact)
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu(playTypeToShow.displayName()) {
                            Picker("Shared.PlayType", selection: $playTypeToShow) {
                                Text(verbatim: "SP")
                                    .tag(IIDXPlayType.single)
                                Text(verbatim: "DP")
                                    .tag(IIDXPlayType.double)
                            }
                            .pickerStyle(.inline)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if dataState == .initializing || dataState == .loading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }
            }
            .refreshable {
                clearTypePerImportGroupCache = Data()
                djLevelPerImportGroupCache = Data()
                await reload()
                debugPrint("Reloaded from swipe to refresh")
            }
            .task {
                if dataState == .initializing {
                    await reload()
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
