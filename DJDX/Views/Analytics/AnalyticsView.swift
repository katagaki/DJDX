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

// swiftlint:disable type_body_length
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

    // Level ordering
    @AppStorage(wrappedValue: Data(), "Analytics.LevelOrder") var levelOrderData: Data
    @State var levelOrder: [Int] = Array(1...12)

    // Per-level category visibility
    @AppStorage(wrappedValue: Data(), "Analytics.PerLevelCategories") var perLevelCategoriesData: Data
    @State var visiblePerLevelCategories: Set<AnalyticsPerLevelCategory> =
        AnalyticsPerLevelCategory.defaultVisible

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
    @State var newAssistClears: [NewClearEntry] = []
    @State var newEasyClears: [NewClearEntry] = []
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
                clearTypeOverallCard
                    .padding(.horizontal)
                    .padding(.top, 8.0)

                LazyVGrid(columns: cardColumns, spacing: 12.0) {
                    ForEach(cardOrder, id: \.self) { cardType in
                        switch cardType {
                        case .clearTypeOverall:
                            EmptyView()
                        case .newClears:
                            newClearsCard
                        case .newAssistClears:
                            newAssistClearsCard
                        case .newEasyClears:
                            newEasyClearsCard
                        case .newHighScores:
                            newHighScoresCard
                        }
                    }

                    // Per-level cards
                    ForEach(orderedVisibleLevels, id: \.self) { difficulty in
                        ForEach(orderedVisiblePerLevelCategories, id: \.self) { category in
                            perLevelCard(difficulty: difficulty, category: category)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4.0)
                .padding(.bottom, 16.0)
            }
            .navigator("ViewTitle.Analytics")
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
                loadLevelOrder()
                loadPerLevelCategories()
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
                        OverviewClearTypeOverallGraph(
                            graphData: .constant(filteredClearTypeData),
                            isInteractive: true
                        )
                        .chartLegend(
                            position: .bottom,
                            alignment: .leading,
                            spacing: 16.0
                        )
                        .padding()
                        .navigationTitle("Analytics.ClearType.Overall")
                        .automaticNavigationTransition(id: "ClearType.Overall", in: analyticsNamespace)
                    case .clearTypePerDifficultyGraph:
                        VStack {
                            OverviewClearTypePerDifficultyGraph(
                                graphData: $clearTypePerDifficulty,
                                difficulty: $levelFilterForOverviewClearType
                            )
                            .chartLegend(
                                position: .bottom,
                                alignment: .leading,
                                spacing: 16.0
                            )
                            DifficultyPicker(
                                selection: $levelFilterForOverviewClearType,
                                difficulties: .constant(difficulties)
                            )
                        }
                        .padding(.top)
                        .padding()
                        .navigationTitle("Analytics.ClearType.ByDifficulty")
                        .automaticNavigationTransition(id: "ClearType.ByDifficulty", in: analyticsNamespace)
                    case .scoreRatePerDifficultyGraph:
                        VStack {
                            OverviewDJLevelPerDifficultyGraph(
                                graphData: $djLevelPerDifficulty,
                                difficulty: $levelFilterForOverviewScoreRate
                            )
                            .chartLegend(
                                position: .bottom,
                                alignment: .leading,
                                spacing: 16.0
                            )
                            DifficultyPicker(
                                selection: $levelFilterForOverviewScoreRate,
                                difficulties: .constant(difficulties)
                            )
                            .padding(.top)
                        }
                        .padding()
                        .navigationTitle("Analytics.DJLevel.ByDifficulty")
                        .automaticNavigationTransition(id: "DJLevel.ByDifficulty", in: analyticsNamespace)
                    case .trendsClearTypeGraph:
                        VStack {
                            TrendsClearTypeGraph(
                                graphData: $clearTypePerImportGroup,
                                difficulty: $levelFilterForTrendsClearType
                            )
                            .chartLegend(.visible)
                            DifficultyPicker(
                                selection: $levelFilterForTrendsClearType,
                                difficulties: .constant(difficulties)
                            )
                            .padding(.top)
                        }
                        .padding()
                        .navigationTitle("Analytics.Trends.ClearType")
                        .automaticNavigationTransition(id: "Trends.ClearType", in: analyticsNamespace)
                    case .trendsDJLevelGraph:
                        VStack {
                            TrendsDJLevelGraph(
                                graphData: $djLevelPerImportGroup,
                                difficulty: $levelFilterForTrendsDJLevel
                            )
                            .chartLegend(.visible)
                            DifficultyPicker(
                                selection: $levelFilterForTrendsDJLevel,
                                difficulties: .constant(difficulties)
                            )
                            .padding(.top)
                        }
                        .padding()
                        .navigationTitle("Analytics.Trends.DJLevel")
                        .automaticNavigationTransition(id: "Trends.DJLevel", in: analyticsNamespace)
                    case .clearTypeForLevel(let difficulty):
                        OverviewClearTypePerDifficultyGraph(
                            graphData: $clearTypePerDifficulty,
                            difficulty: .constant(difficulty)
                        )
                        .chartLegend(.visible)
                        .padding()
                        .navigationTitle("LEVEL \(difficulty)")
                        .automaticNavigationTransition(
                            id: "ClearType.Level.\(difficulty)", in: analyticsNamespace
                        )
                    case .clearTypeTrendsForLevel(let difficulty):
                        TrendsClearTypeGraph(
                            graphData: $clearTypePerImportGroup,
                            difficulty: .constant(difficulty)
                        )
                        .chartLegend(.visible)
                        .padding()
                        .navigationTitle("LEVEL \(difficulty)")
                        .automaticNavigationTransition(
                            id: "ClearTypeTrends.Level.\(difficulty)", in: analyticsNamespace
                        )
                    case .djLevelForLevel(let difficulty):
                        OverviewDJLevelPerDifficultyGraph(
                            graphData: $djLevelPerDifficulty,
                            difficulty: .constant(difficulty)
                        )
                        .chartLegend(.visible)
                        .padding()
                        .navigationTitle("LEVEL \(difficulty)")
                        .automaticNavigationTransition(
                            id: "DJLevel.Level.\(difficulty)", in: analyticsNamespace
                        )
                    case .djLevelTrendsForLevel(let difficulty):
                        TrendsDJLevelGraph(
                            graphData: $djLevelPerImportGroup,
                            difficulty: .constant(difficulty)
                        )
                        .chartLegend(.visible)
                        .padding()
                        .navigationTitle("LEVEL \(difficulty)")
                        .automaticNavigationTransition(
                            id: "DJLevelTrends.Level.\(difficulty)", in: analyticsNamespace
                        )
                    case .newClearsDetail:
                        NewClearsDetailView(newClears: $newClears)
                            .automaticNavigationTransition(id: "NewClears", in: analyticsNamespace)
                    case .newAssistClearsDetail:
                        NewClearsDetailView(newClears: $newAssistClears)
                            .automaticNavigationTransition(
                                id: "NewAssistClears", in: analyticsNamespace
                            )
                    case .newEasyClearsDetail:
                        NewClearsDetailView(newClears: $newEasyClears)
                            .automaticNavigationTransition(
                                id: "NewEasyClears", in: analyticsNamespace
                            )
                    case .newHighScoresDetail:
                        NewHighScoresDetailView(newHighScores: $newHighScores)
                            .automaticNavigationTransition(id: "NewHighScores", in: analyticsNamespace)
                    default: Color.clear
                    }
                }
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
            Section("Analytics.Settings.PerLevel") {
                ForEach(AnalyticsPerLevelCategory.allCases) { category in
                    Toggle(isOn: Binding<Bool>(
                        get: { visiblePerLevelCategories.contains(category) },
                        set: { newValue in
                            withAnimation(.snappy) {
                                if newValue {
                                    visiblePerLevelCategories.insert(category)
                                } else {
                                    visiblePerLevelCategories.remove(category)
                                }
                                savePerLevelCategories()
                            }
                        }
                    )) {
                        Label(LocalizedStringKey(category.titleKey),
                              systemImage: category.systemImage)
                    }
                }
            }
            Section("Analytics.Settings.Levels") {
                ForEach(difficulties, id: \.self) { difficulty in
                    Toggle(isOn: Binding<Bool>(
                        get: { visibleLevels.contains(difficulty) },
                        set: { newValue in
                            withAnimation(.snappy) {
                                if newValue {
                                    visibleLevels.insert(difficulty)
                                } else {
                                    visibleLevels.remove(difficulty)
                                }
                                saveVisibleLevels()
                            }
                        }
                    )) {
                        Text("LEVEL \(difficulty)")
                    }
                }
            }
        } label: {
            Image(systemName: "gearshape")
        }
        .menuActionDismissBehavior(.disabled)
    }

    // MARK: - Card Order Editor

    var cardOrderEditor: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(cardOrder, id: \.self) { cardType in
                        HStack(spacing: 12.0) {
                            Image(systemName: cardType.systemImage)
                                .foregroundStyle(cardType.iconColor)
                                .frame(width: 24.0)
                            cardType.titleText
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
                Section("Analytics.Settings.PerLevel") {
                    ForEach(levelOrder, id: \.self) { difficulty in
                        HStack(spacing: 12.0) {
                            Image(systemName: "chart.pie.fill")
                                .foregroundStyle(.purple)
                                .frame(width: 24.0)
                            Text(verbatim: "LEVEL \(difficulty)")
                            if !visibleLevels.contains(difficulty) {
                                Spacer()
                                Text("Analytics.Settings.Hidden")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onMove(perform: moveLevels)
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Analytics.Settings.EditCards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.snappy) {
                            cardOrder = AnalyticsCardType.defaultOrder
                            levelOrder = Array(1...12)
                            visiblePerLevelCategories = AnalyticsPerLevelCategory.defaultVisible
                            saveCardOrder()
                            saveLevelOrder()
                            savePerLevelCategories()
                        }
                    } label: {
                        Text("Analytics.Settings.ResetOrder")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26.0, *) {
                        Button(role: .confirm) {
                            isEditingCards = false
                        }
                    } else {
                        Button(.sharedDone) {
                            isEditingCards = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Card Views

    var clearTypeOverallCard: some View {
        AnalyticsCardView(cardType: .clearTypeOverall) {
            OverviewClearTypeOverallGraph(graphData: .constant(filteredClearTypeData))
                .chartLegend(.hidden)
                .chartYAxis(.hidden)
        }
        .automaticMatchedTransitionSource(id: "ClearType.Overall", in: analyticsNamespace)
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
        .automaticMatchedTransitionSource(id: "NewClears", in: analyticsNamespace)
        .onTapGesture {
            if !isEditingCards {
                navigationManager.push(.newClearsDetail, for: .analytics)
            }
        }
    }

    var newAssistClearsCard: some View {
        AnalyticsCardView(cardType: .newAssistClears) {
            NewClearsCard(newClears: $newAssistClears)
        }
        .automaticMatchedTransitionSource(id: "NewAssistClears", in: analyticsNamespace)
        .onTapGesture {
            if !isEditingCards {
                navigationManager.push(.newAssistClearsDetail, for: .analytics)
            }
        }
    }

    var newEasyClearsCard: some View {
        AnalyticsCardView(cardType: .newEasyClears) {
            NewClearsCard(newClears: $newEasyClears)
        }
        .automaticMatchedTransitionSource(id: "NewEasyClears", in: analyticsNamespace)
        .onTapGesture {
            if !isEditingCards {
                navigationManager.push(.newEasyClearsDetail, for: .analytics)
            }
        }
    }

    var newHighScoresCard: some View {
        AnalyticsCardView(cardType: .newHighScores) {
            NewHighScoresCard(newHighScores: $newHighScores)
        }
        .automaticMatchedTransitionSource(id: "NewHighScores", in: analyticsNamespace)
        .onTapGesture {
            if !isEditingCards {
                navigationManager.push(.newHighScoresDetail, for: .analytics)
            }
        }
    }

    // MARK: - Per-Level Card Views

    var orderedVisiblePerLevelCategories: [AnalyticsPerLevelCategory] {
        AnalyticsPerLevelCategory.allCases.filter { visiblePerLevelCategories.contains($0) }
    }

    @ViewBuilder
    func perLevelCard(difficulty: Int, category: AnalyticsPerLevelCategory) -> some View {
        switch category {
        case .clearRate:
            clearTypeForLevelCard(difficulty: difficulty)
        case .clearRateTrend:
            clearTypeTrendsForLevelCard(difficulty: difficulty)
        case .djLevel:
            djLevelForLevelCard(difficulty: difficulty)
        case .djLevelTrend:
            djLevelTrendsForLevelCard(difficulty: difficulty)
        }
    }

    func clearTypeForLevelCard(difficulty: Int) -> some View {
        AnalyticsCardView(verbatimTitle: "LEVEL \(difficulty)",
                          systemImage: "chart.pie.fill",
                          iconColor: .purple) {
            OverviewClearTypePerDifficultyGraph(
                graphData: $clearTypePerDifficulty,
                difficulty: .constant(difficulty)
            )
            .chartLegend(.hidden)
            .chartYAxis(.hidden)
        }
        .automaticMatchedTransitionSource(id: "ClearType.Level.\(difficulty)", in: analyticsNamespace)
        .onTapGesture {
            if !isEditingCards && clearTypePerDifficulty[difficulty] != nil {
                navigationManager.push(.clearTypeForLevel(difficulty: difficulty), for: .analytics)
            }
        }
    }

    func clearTypeTrendsForLevelCard(difficulty: Int) -> some View {
        AnalyticsCardView(verbatimTitle: "LEVEL \(difficulty)",
                          systemImage: "chart.xyaxis.line",
                          iconColor: .cyan) {
            TrendsClearTypeGraph(graphData: $clearTypePerImportGroup,
                                 difficulty: .constant(difficulty))
                .chartLegend(.hidden)
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
        }
        .automaticMatchedTransitionSource(
            id: "ClearTypeTrends.Level.\(difficulty)", in: analyticsNamespace
        )
        .onTapGesture {
            if !isEditingCards && clearTypePerImportGroup.count > 0 {
                navigationManager.push(.clearTypeTrendsForLevel(difficulty: difficulty), for: .analytics)
            }
        }
    }

    func djLevelForLevelCard(difficulty: Int) -> some View {
        AnalyticsCardView(verbatimTitle: "LEVEL \(difficulty)",
                          systemImage: "chart.bar.fill",
                          iconColor: .pink) {
            OverviewDJLevelPerDifficultyGraph(
                graphData: $djLevelPerDifficulty,
                difficulty: .constant(difficulty)
            )
            .chartLegend(.hidden)
            .chartYAxis(.hidden)
        }
        .automaticMatchedTransitionSource(id: "DJLevel.Level.\(difficulty)", in: analyticsNamespace)
        .onTapGesture {
            if !isEditingCards && djLevelPerDifficulty[difficulty] != nil {
                navigationManager.push(.djLevelForLevel(difficulty: difficulty), for: .analytics)
            }
        }
    }

    func djLevelTrendsForLevelCard(difficulty: Int) -> some View {
        AnalyticsCardView(verbatimTitle: "LEVEL \(difficulty)",
                          systemImage: "chart.xyaxis.line",
                          iconColor: .teal) {
            TrendsDJLevelGraph(graphData: $djLevelPerImportGroup,
                               difficulty: .constant(difficulty))
                .chartLegend(.hidden)
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
        }
        .automaticMatchedTransitionSource(
            id: "DJLevelTrends.Level.\(difficulty)", in: analyticsNamespace
        )
        .onTapGesture {
            if !isEditingCards && djLevelPerImportGroup.count > 0 {
                navigationManager.push(.djLevelTrendsForLevel(difficulty: difficulty), for: .analytics)
            }
        }
    }

    // MARK: - Filtered Data

    var orderedVisibleLevels: [Int] {
        levelOrder.filter { visibleLevels.contains($0) }
    }

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

    func loadLevelOrder() {
        if let decoded = try? JSONDecoder().decode([Int].self, from: levelOrderData),
           !decoded.isEmpty {
            var order = decoded
            // Ensure all levels 1-12 are present
            for level in difficulties where !order.contains(level) {
                order.append(level)
            }
            order.removeAll { !difficulties.contains($0) }
            levelOrder = order
        }
    }

    func saveLevelOrder() {
        levelOrderData = (try? JSONEncoder().encode(levelOrder)) ?? Data()
    }

    func moveLevels(from source: IndexSet, to destination: Int) {
        levelOrder.move(fromOffsets: source, toOffset: destination)
        saveLevelOrder()
    }

    func loadPerLevelCategories() {
        if let decoded = try? JSONDecoder().decode(
            Set<AnalyticsPerLevelCategory>.self, from: perLevelCategoriesData
        ) {
            visiblePerLevelCategories = decoded
        }
    }

    func savePerLevelCategories() {
        perLevelCategoriesData = (try? JSONEncoder().encode(visiblePerLevelCategories)) ?? Data()
    }
}
// swiftlint:enable type_body_length
