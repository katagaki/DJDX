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

    // Card ordering
    @AppStorage(wrappedValue: Data(), "Analytics.CardOrder") var cardOrderData: Data
    @State var cardOrder: [AnalyticsCardType] = AnalyticsCardType.defaultOrder
    @State var isEditingCards: Bool = false

    // Level filter visibility (settings)
    @AppStorage(wrappedValue: Data(), "Analytics.VisibleLevels") var visibleLevelsData: Data
    @State var visibleLevels: Set<Int> = Set(1...12)

    // Overall
    @State var clearTypePerDifficulty: [Int: OrderedDictionary<String, Int>] = [:]
    @State var djLevelPerDifficulty: [Int: [IIDXDJLevel: Int]] = [:]

    // Trends
    @State var clearTypePerImportGroup: [Date: [Int: OrderedDictionary<String, Int>]] = [:]
    @AppStorage(wrappedValue: Data(), "Analytics.Trends.ClearType.Level.Cache") var clearTypePerImportGroupCache: Data
    @State var djLevelPerImportGroup: [Date: [Int: OrderedDictionary<String, Int>]] = [:]
    @AppStorage(wrappedValue: Data(), "Analytics.Trends.DJLevel.Level.Cache") var djLevelPerImportGroupCache: Data

    // New Clears & High Scores
    @State var newClears: [NewClearEntry] = []
    @State var newHighScores: [NewHighScoreEntry] = []

    @State var dataState: DataState = .initializing

    let difficulties: [Int] = Array(1...12)

    let cardColumns = [
        GridItem(.flexible(), spacing: 12.0),
        GridItem(.flexible(), spacing: 12.0)
    ]

    @Namespace var analyticsNamespace

    var body: some View {
        NavigationStack(path: $navigationManager[.analytics]) {
            ScrollView {
                LazyVGrid(columns: cardColumns, spacing: 12.0) {
                    ForEach(cardOrder, id: \.self) { cardType in
                        let isFullWidth = cardType.isFullWidth
                        Group {
                            switch cardType {
                            case .clearTypeOverall:
                                clearTypeOverallCard
                            case .newClears:
                                newClearsCard
                            case .newHighScores:
                                newHighScoresCard
                            case .clearTypeByDifficulty:
                                clearTypeByDifficultyCard
                            case .clearTypeTrends:
                                clearTypeTrendsCard
                            case .djLevelByDifficulty:
                                djLevelByDifficultyCard
                            case .djLevelTrends:
                                djLevelTrendsCard
                            }
                        }
                        .gridCellColumns(isFullWidth ? 2 : 1)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8.0)
                .padding(.bottom, 16.0)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ViewTitle.Analytics")
            .navigationBarTitleDisplayMode(.automatic)
            .sheet(isPresented: $isEditingCards) {
                cardOrderEditor
            }
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
                    } else {
                        settingsMenu
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
                loadCardOrder()
                loadVisibleLevels()
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
                        VStack {
                            OverviewClearTypePerDifficultyGraph(graphData: $clearTypePerDifficulty,
                                                                difficulty: $levelFilterForOverviewClearType,
                                                                legendPosition: .bottom)
                            DifficultyPicker(selection: $levelFilterForOverviewClearType,
                                             difficulties: .constant(difficulties))
                                .padding(.top)
                        }
                        .navigationTitle("Analytics.ClearType.ByDifficulty")
                        .automaticNavigationTransition(id: "ClearType.ByDifficulty", in: analyticsNamespace)
                    case .scoreRatePerDifficultyGraph:
                        VStack {
                            OverviewDJLevelPerDifficultyGraph(graphData: $djLevelPerDifficulty,
                                                              difficulty: $levelFilterForOverviewScoreRate)
                            DifficultyPicker(selection: $levelFilterForOverviewScoreRate,
                                             difficulties: .constant(difficulties))
                                .padding(.top)
                        }
                        .navigationTitle("Analytics.DJLevel.ByDifficulty")
                        .automaticNavigationTransition(id: "DJLevel.ByDifficulty", in: analyticsNamespace)
                    case .trendsClearTypeGraph:
                        VStack {
                            TrendsClearTypeGraph(graphData: $clearTypePerImportGroup,
                                                 difficulty: $levelFilterForTrendsClearType)
                            DifficultyPicker(selection: $levelFilterForTrendsClearType,
                                             difficulties: .constant(difficulties))
                                .padding(.top)
                        }
                        .navigationTitle("Analytics.Trends.ClearType")
                        .automaticNavigationTransition(id: "Trends.ClearType", in: analyticsNamespace)
                    case .trendsDJLevelGraph:
                        VStack {
                            TrendsDJLevelGraph(graphData: $djLevelPerImportGroup,
                                               difficulty: $levelFilterForTrendsDJLevel)
                            DifficultyPicker(selection: $levelFilterForTrendsDJLevel,
                                             difficulties: .constant(difficulties))
                                .padding(.top)
                        }
                        .navigationTitle("Analytics.Trends.DJLevel")
                        .automaticNavigationTransition(id: "Trends.DJLevel", in: analyticsNamespace)
                    case .newClearsDetail:
                        NewClearsDetailView(newClears: $newClears)
                    case .newHighScoresDetail:
                        NewHighScoresDetailView(newHighScores: $newHighScores)
                    default: Color.clear
                    }
                }
                .padding()
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    // MARK: - Settings Menu

    var settingsMenu: some View {
        Menu {
            Section {
                Button {
                    isEditingCards = true
                } label: {
                    Label("Analytics.Settings.EditCards",
                          systemImage: "arrow.up.arrow.down")
                }
            }
            Section("Analytics.Settings.Levels") {
                ForEach(difficulties, id: \.self) { difficulty in
                    Button {
                        withAnimation(.snappy) {
                            if visibleLevels.contains(difficulty) {
                                visibleLevels.remove(difficulty)
                            } else {
                                visibleLevels.insert(difficulty)
                            }
                            saveVisibleLevels()
                        }
                    } label: {
                        HStack {
                            Text("LEVEL \(difficulty)")
                            Spacer()
                            if visibleLevels.contains(difficulty) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "gearshape")
        }
    }

    // MARK: - Card Order Editor

    var cardOrderEditor: some View {
        NavigationStack {
            List {
                ForEach(cardOrder, id: \.self) { cardType in
                    HStack(spacing: 12.0) {
                        Image(systemName: cardType.systemImage)
                            .foregroundStyle(cardType.iconColor)
                            .frame(width: 24.0)
                        Text(LocalizedStringKey(cardType.titleKey))
                        Spacer()
                        if cardType.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .moveDisabled(cardType.isPinned)
                }
                .onMove(perform: moveCards)
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Analytics.Settings.EditCards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.snappy) {
                            cardOrder = AnalyticsCardType.defaultOrder
                            saveCardOrder()
                        }
                    } label: {
                        Text("Analytics.Settings.ResetOrder")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isEditingCards = false
                    } label: {
                        Text("Analytics.Settings.DoneEditing")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - Card Views

    var clearTypeOverallCard: some View {
        AnalyticsCardView(cardType: .clearTypeOverall) {
            OverviewClearTypeOverallGraph(graphData: .constant(filteredClearTypeData))
                .frame(height: 160.0)
                .chartLegend(.hidden)
                .automaticMatchedTransitionSource(id: "ClearType.Overall", in: analyticsNamespace)
        }
        .onTapGesture {
            if !isEditingCards && clearTypePerDifficulty.count > 0 {
                navigationManager.push(.clearTypeOverviewGraph, for: .analytics)
            }
        }
    }

    var newClearsCard: some View {
        AnalyticsCardView(cardType: .newClears) {
            NewClearsCard(newClears: $newClears)
        }
        .onTapGesture {
            if !isEditingCards {
                navigationManager.push(.newClearsDetail, for: .analytics)
            }
        }
    }

    var newHighScoresCard: some View {
        AnalyticsCardView(cardType: .newHighScores) {
            NewHighScoresCard(newHighScores: $newHighScores)
        }
        .onTapGesture {
            if !isEditingCards {
                navigationManager.push(.newHighScoresDetail, for: .analytics)
            }
        }
    }

    var clearTypeByDifficultyCard: some View {
        AnalyticsCardView(cardType: .clearTypeByDifficulty) {
            OverviewClearTypePerDifficultyGraph(graphData: .constant(filteredClearTypeData),
                                                difficulty: $levelFilterForOverviewClearType,
                                                legendPosition: .trailing)
                .frame(height: 100.0)
                .chartLegend(.hidden)
                .automaticMatchedTransitionSource(id: "ClearType.ByDifficulty", in: analyticsNamespace)
        }
        .onTapGesture {
            if !isEditingCards && clearTypePerDifficulty.count > 0 {
                navigationManager.push(.clearTypePerDifficultyGraph, for: .analytics)
            }
        }
    }

    var clearTypeTrendsCard: some View {
        AnalyticsCardView(cardType: .clearTypeTrends) {
            TrendsClearTypeGraph(graphData: $clearTypePerImportGroup,
                                 difficulty: $levelFilterForTrendsClearType)
                .frame(height: 100.0)
                .chartLegend(.hidden)
                .automaticMatchedTransitionSource(id: "Trends.ClearType", in: analyticsNamespace)
        }
        .onTapGesture {
            if !isEditingCards && clearTypePerImportGroup.count > 0 {
                navigationManager.push(.trendsClearTypeGraph, for: .analytics)
            }
        }
    }

    var djLevelByDifficultyCard: some View {
        AnalyticsCardView(cardType: .djLevelByDifficulty) {
            OverviewDJLevelPerDifficultyGraph(graphData: $djLevelPerDifficulty,
                                              difficulty: $levelFilterForOverviewScoreRate)
                .frame(height: 100.0)
                .chartLegend(.hidden)
                .automaticMatchedTransitionSource(id: "DJLevel.ByDifficulty", in: analyticsNamespace)
        }
        .onTapGesture {
            if !isEditingCards && djLevelPerDifficulty.count > 0 {
                navigationManager.push(.scoreRatePerDifficultyGraph, for: .analytics)
            }
        }
    }

    var djLevelTrendsCard: some View {
        AnalyticsCardView(cardType: .djLevelTrends) {
            TrendsDJLevelGraph(graphData: $djLevelPerImportGroup,
                               difficulty: $levelFilterForTrendsDJLevel)
                .frame(height: 100.0)
                .chartLegend(.hidden)
                .automaticMatchedTransitionSource(id: "Trends.DJLevel", in: analyticsNamespace)
        }
        .onTapGesture {
            if !isEditingCards && djLevelPerImportGroup.count > 0 {
                navigationManager.push(.trendsDJLevelGraph, for: .analytics)
            }
        }
    }

    // MARK: - Filtered Data

    var filteredClearTypeData: [Int: OrderedDictionary<String, Int>] {
        clearTypePerDifficulty.filter { visibleLevels.contains($0.key) }
    }

    // MARK: - Card Ordering

    func moveCards(from source: IndexSet, to destination: Int) {
        // Prevent moving past the pinned clearTypeOverall card at index 0
        let pinnedCount = cardOrder.prefix(while: { $0.isPinned }).count
        let adjustedDestination = max(destination, pinnedCount)
        var adjustedSource = source
        for index in source {
            if index < pinnedCount {
                adjustedSource.remove(index)
            }
        }
        guard !adjustedSource.isEmpty else { return }
        cardOrder.move(fromOffsets: adjustedSource, toOffset: adjustedDestination)
        saveCardOrder()
    }

    func loadCardOrder() {
        if let decoded = try? JSONDecoder().decode([AnalyticsCardType].self, from: cardOrderData),
           !decoded.isEmpty {
            // Ensure all card types are present (handle new card types added in updates)
            var order = decoded
            for cardType in AnalyticsCardType.defaultOrder where !order.contains(cardType) {
                order.append(cardType)
            }
            order.removeAll { !AnalyticsCardType.defaultOrder.contains($0) }
            cardOrder = order
        }
    }

    func saveCardOrder() {
        cardOrderData = (try? JSONEncoder().encode(cardOrder)) ?? Data()
    }

    func loadVisibleLevels() {
        if let decoded = try? JSONDecoder().decode(Set<Int>.self, from: visibleLevelsData),
           !decoded.isEmpty {
            visibleLevels = decoded
        }
    }

    func saveVisibleLevels() {
        visibleLevelsData = (try? JSONEncoder().encode(visibleLevels)) ?? Data()
    }
}
