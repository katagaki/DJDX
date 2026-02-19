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
import UniformTypeIdentifiers

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

    // Drag state
    @State var draggedCard: AnalyticsCardType?
    @State var draggedLevel: Int?

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

    // swiftlint:disable function_body_length
    var body: some View {
        NavigationStack(path: $navigationManager[.analytics]) {
            ScrollView {
                if isEditingCards {
                    clearTypeOverallCard
                        .jiggle(isActive: true, seed: 0)
                        .padding(.horizontal)
                        .padding(.top, 8.0)
                } else {
                    clearTypeOverallCard
                        .padding(.horizontal)
                        .padding(.top, 8.0)
                }

                LazyVGrid(columns: cardColumns, spacing: 12.0) {
                    ForEach(cardOrder, id: \.self) { cardType in
                        switch cardType {
                        case .clearTypeOverall:
                            EmptyView()
                        case .newClears:
                            newClearsCard
                                .cardDraggable(cardType, editing: isEditingCards,
                                               draggedCard: $draggedCard, cardOrder: $cardOrder,
                                               onReorder: saveCardOrder, seed: 1)
                        case .newAssistClears:
                            newAssistClearsCard
                                .cardDraggable(cardType, editing: isEditingCards,
                                               draggedCard: $draggedCard, cardOrder: $cardOrder,
                                               onReorder: saveCardOrder, seed: 2)
                        case .newEasyClears:
                            newEasyClearsCard
                                .cardDraggable(cardType, editing: isEditingCards,
                                               draggedCard: $draggedCard, cardOrder: $cardOrder,
                                               onReorder: saveCardOrder, seed: 3)
                        case .newHighScores:
                            newHighScoresCard
                                .cardDraggable(cardType, editing: isEditingCards,
                                               draggedCard: $draggedCard, cardOrder: $cardOrder,
                                               onReorder: saveCardOrder, seed: 4)
                        }
                    }

                    // Per-level cards
                    ForEach(orderedVisibleLevels, id: \.self) { difficulty in
                        ForEach(orderedVisiblePerLevelCategories, id: \.self) { category in
                            perLevelCard(difficulty: difficulty, category: category)
                                .levelDraggable(difficulty, category: category,
                                                editing: isEditingCards,
                                                draggedLevel: $draggedLevel,
                                                levelOrder: $levelOrder,
                                                onReorder: saveLevelOrder)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4.0)
                .padding(.bottom, 16.0)
            }
            .navigator("ViewTitle.Analytics")
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) {
                        if !isEditingCards {
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
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditingCards {
                        if #available(iOS 26.0, *) {
                            Button(role: .confirm) {
                                withAnimation(.snappy) {
                                    isEditingCards = false
                                    draggedCard = nil
                                    draggedLevel = nil
                                }
                            }
                        } else {
                            Button(.sharedDone) {
                                withAnimation(.snappy) {
                                    isEditingCards = false
                                    draggedCard = nil
                                    draggedLevel = nil
                                }
                            }
                        }
                    } else if dataState == .initializing || dataState == .loading {
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
    // swiftlint:enable function_body_length

    // MARK: - Settings Menu

    var settingsMenu: some View {
        Menu {
            Section {
                Button {
                    withAnimation(.snappy) { isEditingCards = true }
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

    // MARK: - Card Views

    var clearTypeOverallCard: some View {
        Button {
            if !isEditingCards && clearTypePerDifficulty.count > 0 {
                navigationManager.push(.clearTypeOverviewGraph, for: .analytics)
            }
        } label: {
            AnalyticsCardView(cardType: .clearTypeOverall) {
                OverviewClearTypeOverallGraph(graphData: .constant(filteredClearTypeData))
                    .chartLegend(.hidden)
                    .chartYAxis(.hidden)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "ClearType.Overall", in: analyticsNamespace)
    }

    var newClearsCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(.newClearsDetail, for: .analytics)
            }
        } label: {
            AnalyticsCardView(cardType: .newClears) {
                NewClearsCard(newClears: $newClears)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewClears", in: analyticsNamespace)
    }

    var newAssistClearsCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(.newAssistClearsDetail, for: .analytics)
            }
        } label: {
            AnalyticsCardView(cardType: .newAssistClears) {
                NewClearsCard(newClears: $newAssistClears)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewAssistClears", in: analyticsNamespace)
    }

    var newEasyClearsCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(.newEasyClearsDetail, for: .analytics)
            }
        } label: {
            AnalyticsCardView(cardType: .newEasyClears) {
                NewClearsCard(newClears: $newEasyClears)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewEasyClears", in: analyticsNamespace)
    }

    var newHighScoresCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(.newHighScoresDetail, for: .analytics)
            }
        } label: {
            AnalyticsCardView(cardType: .newHighScores) {
                NewHighScoresCard(newHighScores: $newHighScores)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewHighScores", in: analyticsNamespace)
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
        Button {
            if !isEditingCards && clearTypePerDifficulty[difficulty] != nil {
                navigationManager.push(.clearTypeForLevel(difficulty: difficulty), for: .analytics)
            }
        } label: {
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
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "ClearType.Level.\(difficulty)", in: analyticsNamespace)
    }

    func clearTypeTrendsForLevelCard(difficulty: Int) -> some View {
        Button {
            if !isEditingCards && clearTypePerImportGroup.count > 0 {
                navigationManager.push(.clearTypeTrendsForLevel(difficulty: difficulty), for: .analytics)
            }
        } label: {
            AnalyticsCardView(verbatimTitle: "LEVEL \(difficulty)",
                              systemImage: "chart.xyaxis.line",
                              iconColor: .cyan) {
                TrendsClearTypeGraph(graphData: $clearTypePerImportGroup,
                                     difficulty: .constant(difficulty))
                    .chartLegend(.hidden)
                    .chartYAxis(.hidden)
                    .chartXAxis(.hidden)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(
            id: "ClearTypeTrends.Level.\(difficulty)", in: analyticsNamespace
        )
    }

    func djLevelForLevelCard(difficulty: Int) -> some View {
        Button {
            if !isEditingCards && djLevelPerDifficulty[difficulty] != nil {
                navigationManager.push(.djLevelForLevel(difficulty: difficulty), for: .analytics)
            }
        } label: {
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
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "DJLevel.Level.\(difficulty)", in: analyticsNamespace)
    }

    func djLevelTrendsForLevelCard(difficulty: Int) -> some View {
        Button {
            if !isEditingCards && djLevelPerImportGroup.count > 0 {
                navigationManager.push(.djLevelTrendsForLevel(difficulty: difficulty), for: .analytics)
            }
        } label: {
            AnalyticsCardView(verbatimTitle: "LEVEL \(difficulty)",
                              systemImage: "chart.xyaxis.line",
                              iconColor: .teal) {
                TrendsDJLevelGraph(graphData: $djLevelPerImportGroup,
                                   difficulty: .constant(difficulty))
                    .chartLegend(.hidden)
                    .chartYAxis(.hidden)
                    .chartXAxis(.hidden)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(
            id: "DJLevelTrends.Level.\(difficulty)", in: analyticsNamespace
        )
    }

    // MARK: - Filtered Data

    var orderedVisibleLevels: [Int] {
        levelOrder.filter { visibleLevels.contains($0) }
    }

    var filteredClearTypeData: [Int: OrderedDictionary<String, Int>] {
        clearTypePerDifficulty.filter { visibleLevels.contains($0.key) }
    }

    // MARK: - Card Ordering

    func loadCardOrder() {
        if let decoded = try? JSONDecoder().decode([AnalyticsCardType].self, from: cardOrderData),
           !decoded.isEmpty {
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

// MARK: - Drag-and-Drop View Extensions

extension View {
    @ViewBuilder
    func cardDraggable(
        _ cardType: AnalyticsCardType,
        editing: Bool,
        draggedCard: Binding<AnalyticsCardType?>,
        cardOrder: Binding<[AnalyticsCardType]>,
        onReorder: @escaping () -> Void,
        seed: Int
    ) -> some View {
        if editing {
            self
                .jiggle(isActive: true, seed: seed)
                .opacity(draggedCard.wrappedValue == cardType ? 0.4 : 1.0)
                .onDrag {
                    draggedCard.wrappedValue = cardType
                    return NSItemProvider(object: cardType.rawValue as NSString)
                }
                .onDrop(of: [.text], delegate: CardReorderDropDelegate(
                    target: cardType,
                    cards: cardOrder,
                    draggedCard: draggedCard,
                    onReorder: onReorder
                ))
        } else {
            self
        }
    }

    @ViewBuilder
    func levelDraggable(
        _ difficulty: Int,
        category: AnalyticsPerLevelCategory,
        editing: Bool,
        draggedLevel: Binding<Int?>,
        levelOrder: Binding<[Int]>,
        onReorder: @escaping () -> Void
    ) -> some View {
        let seed = difficulty * 10 + (AnalyticsPerLevelCategory.allCases.firstIndex(of: category) ?? 0)
        if editing {
            self
                .jiggle(isActive: true, seed: seed)
                .opacity(draggedLevel.wrappedValue == difficulty ? 0.4 : 1.0)
                .onDrag {
                    draggedLevel.wrappedValue = difficulty
                    return NSItemProvider(object: "\(difficulty)" as NSString)
                }
                .onDrop(of: [.text], delegate: LevelReorderDropDelegate(
                    target: difficulty,
                    levels: levelOrder,
                    draggedLevel: draggedLevel,
                    onReorder: onReorder
                ))
        } else {
            self
        }
    }
}
