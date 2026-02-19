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

    // Card visibility
    @AppStorage(wrappedValue: Data(), "Analytics.VisibleCards") var visibleCardsData: Data
    @State var visibleCards: Set<AnalyticsCardType> = AnalyticsCardType.defaultVisible

    // Drag state
    @State var draggedCard: AnalyticsCardType?
    @State var draggedPerLevelCard: PerLevelCardID?

    // Level filter visibility (settings)
    @AppStorage(wrappedValue: Data(), "Analytics.VisibleLevels") var visibleLevelsData: Data
    @State var visibleLevels: Set<Int> = [1, 12]

    // Per-level card ordering
    @AppStorage(wrappedValue: Data(), "Analytics.PerLevelCardOrder") var perLevelCardOrderData: Data
    @State var perLevelCardOrder: [PerLevelCardID] = PerLevelCardID.defaultOrder

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
    @State var newFullComboClears: [NewClearEntry] = []
    @State var newHardClears: [NewClearEntry] = []
    @State var newExHardClears: [NewClearEntry] = []
    @State var newFailed: [NewClearEntry] = []
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
                // Overall summary (position fixed)
                clearTypeOverallCard
                    .padding(.horizontal)
                    .padding(.top, 8.0)

                // Summary cards - horizontal scroll
                let visibleSummaryCards = cardOrder.filter {
                    $0.isSummaryCard && visibleCards.contains($0)
                }
                if !visibleSummaryCards.isEmpty {
                    Text("Analytics.Header.NewScores")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .padding(.top, 8.0)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12.0) {
                            ForEach(visibleSummaryCards, id: \.self) { cardType in
                                cardView(for: cardType)
                                    .frame(width: 130.0)
                                    .cardDraggable(cardType, editing: isEditingCards,
                                                   draggedCard: $draggedCard, cardOrder: $cardOrder,
                                                   onReorder: saveCardOrder,
                                                   seed: cardOrder.firstIndex(of: cardType) ?? 0)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Per-level cards
                Text("Analytics.Header.PerLevel")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .padding(.top, 8.0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                LazyVGrid(columns: cardColumns, spacing: 12.0) {
                    ForEach(visiblePerLevelCards, id: \.self) { card in
                        perLevelCard(difficulty: card.difficulty, category: card.category)
                            .perLevelCardDraggable(card, editing: isEditingCards,
                                                   draggedCard: $draggedPerLevelCard,
                                                   cardOrder: $perLevelCardOrder,
                                                   onReorder: savePerLevelCardOrder)
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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isEditingCards {
                        if #available(iOS 26.0, *) {
                            Button(role: .confirm) {
                                withAnimation(.snappy) {
                                    isEditingCards = false
                                    draggedCard = nil
                                    draggedPerLevelCard = nil
                                }
                            }
                        } else {
                            Button(.sharedDone) {
                                withAnimation(.snappy) {
                                    isEditingCards = false
                                    draggedCard = nil
                                    draggedPerLevelCard = nil
                                }
                            }
                        }
                    } else if dataState == .initializing || dataState == .loading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Button {
                            withAnimation(.snappy) { isEditingCards = true }
                        } label: {
                            Label("Analytics.Settings.EditCards",
                                  systemImage: "arrow.up.arrow.down")
                        }
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
                loadVisibleCards()
                loadVisibleLevels()
                loadPerLevelCardOrder()
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
                            TogglableClearTypeDetailView(
                                graphData: $clearTypePerDifficulty,
                                difficulty: $levelFilterForOverviewClearType
                            )
                            DifficultyPicker(
                                selection: $levelFilterForOverviewClearType,
                                difficulties: .constant(difficulties)
                            )
                        }
                        .padding(.top)
                        .navigationTitle("Analytics.ClearType.ByDifficulty")
                        .automaticNavigationTransition(id: "ClearType.ByDifficulty", in: analyticsNamespace)
                    case .scoreRatePerDifficultyGraph:
                        VStack {
                            TogglableDJLevelDetailView(
                                graphData: $djLevelPerDifficulty,
                                difficulty: $levelFilterForOverviewScoreRate
                            )
                            DifficultyPicker(
                                selection: $levelFilterForOverviewScoreRate,
                                difficulties: .constant(difficulties)
                            )
                            .padding(.top)
                        }
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
                        TogglableClearTypeDetailView(
                            graphData: $clearTypePerDifficulty,
                            difficulty: .constant(difficulty)
                        )
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
                        TogglableDJLevelDetailView(
                            graphData: $djLevelPerDifficulty,
                            difficulty: .constant(difficulty)
                        )
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
                        NewClearsDetailView(
                            newClears: $newClears,
                            title: AnalyticsCardType.newClears.titleKey
                        )
                        .automaticNavigationTransition(id: "NewClears", in: analyticsNamespace)
                    case .newAssistClearsDetail:
                        NewClearsDetailView(
                            newClears: $newAssistClears,
                            title: AnalyticsCardType.newAssistClears.titleKey
                        )
                        .automaticNavigationTransition(
                            id: "NewAssistClears", in: analyticsNamespace
                        )
                    case .newEasyClearsDetail:
                        NewClearsDetailView(
                            newClears: $newEasyClears,
                            title: AnalyticsCardType.newEasyClears.titleKey
                        )
                        .automaticNavigationTransition(
                            id: "NewEasyClears", in: analyticsNamespace
                        )
                    case .newFullComboClearDetail:
                        NewClearsDetailView(
                            newClears: $newFullComboClears,
                            title: AnalyticsCardType.newFullComboClear.titleKey
                        )
                        .automaticNavigationTransition(
                            id: "NewFullComboClear", in: analyticsNamespace
                        )
                    case .newHardClearDetail:
                        NewClearsDetailView(
                            newClears: $newHardClears,
                            title: AnalyticsCardType.newHardClear.titleKey
                        )
                        .automaticNavigationTransition(
                            id: "NewHardClear", in: analyticsNamespace
                        )
                    case .newExHardClearDetail:
                        NewClearsDetailView(
                            newClears: $newExHardClears,
                            title: AnalyticsCardType.newExHardClear.titleKey
                        )
                        .automaticNavigationTransition(
                            id: "NewExHardClear", in: analyticsNamespace
                        )
                    case .newFailedDetail:
                        NewClearsDetailView(
                            newClears: $newFailed,
                            title: AnalyticsCardType.newFailed.titleKey
                        )
                        .automaticNavigationTransition(
                            id: "NewFailed", in: analyticsNamespace
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
            Section("Analytics.Settings.Cards") {
                ForEach(AnalyticsCardType.allCases.filter { !$0.isPinned }) { cardType in
                    Toggle(isOn: Binding<Bool>(
                        get: { visibleCards.contains(cardType) },
                        set: { newValue in
                            withAnimation(.snappy) {
                                if newValue {
                                    visibleCards.insert(cardType)
                                } else {
                                    visibleCards.remove(cardType)
                                }
                                saveVisibleCards()
                            }
                        }
                    )) {
                        Label {
                            cardType.titleText
                        } icon: {
                            Image(systemName: cardType.systemImage)
                        }
                    }
                }
            }
            ForEach(difficulties, id: \.self) { difficulty in
                Section("LEVEL \(difficulty)") {
                    ForEach(AnalyticsPerLevelCategory.allCases) { category in
                        let cardID = PerLevelCardID(difficulty: difficulty, category: category)
                        let isLevelVisible = visibleLevels.contains(difficulty)
                        let isCategoryVisible = visiblePerLevelCategories.contains(category)
                        Toggle(isOn: Binding<Bool>(
                            get: {
                                isLevelVisible && isCategoryVisible
                            },
                            set: { newValue in
                                withAnimation(.snappy) {
                                    if newValue {
                                        visibleLevels.insert(difficulty)
                                        visiblePerLevelCategories.insert(category)
                                    } else {
                                        let otherCategoriesForLevel = AnalyticsPerLevelCategory
                                            .allCases.filter { $0 != category }
                                        let hasOtherVisible = otherCategoriesForLevel
                                            .contains { visiblePerLevelCategories.contains($0) }
                                        if !hasOtherVisible {
                                            visibleLevels.remove(difficulty)
                                        }
                                    }
                                    saveVisibleLevels()
                                    savePerLevelCategories()
                                }
                            }
                        )) {
                            Text(LocalizedStringKey(category.titleKey))
                        }
                    }
                    Button("Analytics.Settings.HideAll", role: .destructive) {
                        withAnimation(.snappy) {
                            visibleLevels.remove(difficulty)
                            saveVisibleLevels()
                        }
                    }
                }
                .menuActionDismissBehavior(.disabled)
            }
            Section {
                Button("Analytics.Settings.ResetAll", role: .destructive) {
                    withAnimation(.snappy) {
                        cardOrder = AnalyticsCardType.defaultOrder
                        visibleCards = AnalyticsCardType.defaultVisible
                        visibleLevels = [1, 12]
                        perLevelCardOrder = PerLevelCardID.defaultOrder
                        visiblePerLevelCategories = AnalyticsPerLevelCategory.defaultVisible
                        saveCardOrder()
                        saveVisibleCards()
                        saveVisibleLevels()
                        savePerLevelCardOrder()
                        savePerLevelCategories()
                    }
                }
            }
        } label: {
            Image(systemName: "pencil")
        }
        .menuActionDismissBehavior(.disabled)
    }

    // MARK: - Card Views

    @ViewBuilder
    func cardView(for cardType: AnalyticsCardType) -> some View {
        switch cardType {
        case .clearTypeOverall:
            EmptyView()
        case .newClears:
            newClearsCard
        case .newAssistClears:
            newAssistClearsCard
        case .newEasyClears:
            newEasyClearsCard
        case .newFullComboClear:
            newFullComboClearCard
        case .newHardClear:
            newHardClearCard
        case .newExHardClear:
            newExHardClearCard
        case .newFailed:
            newFailedCard
        case .newHighScores:
            newHighScoresCard
        }
    }

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

    var newFullComboClearCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(.newFullComboClearDetail, for: .analytics)
            }
        } label: {
            AnalyticsCardView(cardType: .newFullComboClear) {
                NewClearsCard(newClears: $newFullComboClears)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewFullComboClear", in: analyticsNamespace)
    }

    var newHardClearCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(.newHardClearDetail, for: .analytics)
            }
        } label: {
            AnalyticsCardView(cardType: .newHardClear) {
                NewClearsCard(newClears: $newHardClears)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewHardClear", in: analyticsNamespace)
    }

    var newExHardClearCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(.newExHardClearDetail, for: .analytics)
            }
        } label: {
            AnalyticsCardView(cardType: .newExHardClear) {
                NewClearsCard(newClears: $newExHardClears)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewExHardClear", in: analyticsNamespace)
    }

    var newFailedCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(.newFailedDetail, for: .analytics)
            }
        } label: {
            AnalyticsCardView(cardType: .newFailed) {
                NewClearsCard(newClears: $newFailed)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewFailed", in: analyticsNamespace)
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

    var visiblePerLevelCards: [PerLevelCardID] {
        perLevelCardOrder.filter { card in
            visibleLevels.contains(card.difficulty) &&
            visiblePerLevelCategories.contains(card.category)
        }
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
                              systemImage: "medal.star",
                              iconColor: .secondary) {
                OverviewClearTypePerDifficultyGraph(
                    graphData: $clearTypePerDifficulty,
                    difficulty: .constant(difficulty)
                )
                .chartLegend(.hidden)
                .chartYAxis(.hidden)
            }
            .perLevelCaption("Analytics.PerLevel.Caption.ClearType")
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
                              systemImage: "medal.star",
                              iconColor: .secondary) {
                TrendsClearTypeGraph(graphData: $clearTypePerImportGroup,
                                     difficulty: .constant(difficulty))
                    .chartLegend(.hidden)
                    .chartYAxis(.hidden)
                    .chartXAxis(.hidden)
            }
            .perLevelCaption("Analytics.PerLevel.Caption.ClearType")
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
                              systemImage: "medal.star",
                              iconColor: .secondary) {
                OverviewDJLevelPerDifficultyGraph(
                    graphData: $djLevelPerDifficulty,
                    difficulty: .constant(difficulty)
                )
                .chartLegend(.hidden)
                .chartYAxis(.hidden)
            }
            .perLevelCaption("Analytics.PerLevel.Caption.DJLevel")
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
                              systemImage: "medal.star",
                              iconColor: .secondary) {
                TrendsDJLevelGraph(graphData: $djLevelPerImportGroup,
                                   difficulty: .constant(difficulty))
                    .chartLegend(.hidden)
                    .chartYAxis(.hidden)
                    .chartXAxis(.hidden)
            }
            .perLevelCaption("Analytics.PerLevel.Caption.DJLevel")
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(
            id: "DJLevelTrends.Level.\(difficulty)", in: analyticsNamespace
        )
    }

    // MARK: - Filtered Data

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

    func loadVisibleCards() {
        if let decoded = try? JSONDecoder().decode(Set<AnalyticsCardType>.self, from: visibleCardsData) {
            var cards = decoded
            for cardType in AnalyticsCardType.allCases where !decoded.contains(cardType) {
                cards.insert(cardType)
            }
            visibleCards = cards
        }
    }

    func saveVisibleCards() {
        visibleCardsData = (try? JSONEncoder().encode(visibleCards)) ?? Data()
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

    func loadPerLevelCardOrder() {
        if let decoded = try? JSONDecoder().decode([PerLevelCardID].self, from: perLevelCardOrderData),
           !decoded.isEmpty {
            var order = decoded
            for card in PerLevelCardID.defaultOrder where !order.contains(card) {
                order.append(card)
            }
            let validCards = Set(PerLevelCardID.defaultOrder)
            order.removeAll { !validCards.contains($0) }
            perLevelCardOrder = order
        }
    }

    func savePerLevelCardOrder() {
        perLevelCardOrderData = (try? JSONEncoder().encode(perLevelCardOrder)) ?? Data()
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
    func perLevelCardDraggable(
        _ card: PerLevelCardID,
        editing: Bool,
        draggedCard: Binding<PerLevelCardID?>,
        cardOrder: Binding<[PerLevelCardID]>,
        onReorder: @escaping () -> Void
    ) -> some View {
        let seed = card.difficulty * 10 +
            (AnalyticsPerLevelCategory.allCases.firstIndex(of: card.category) ?? 0)
        if editing {
            self
                .jiggle(isActive: true, seed: seed)
                .opacity(draggedCard.wrappedValue == card ? 0.4 : 1.0)
                .onDrag {
                    draggedCard.wrappedValue = card
                    return NSItemProvider(object: card.dragIdentifier as NSString)
                }
                .onDrop(of: [.text], delegate: PerLevelCardReorderDropDelegate(
                    target: card,
                    cards: cardOrder,
                    draggedCard: draggedCard,
                    onReorder: onReorder
                ))
        } else {
            self
        }
    }
}
