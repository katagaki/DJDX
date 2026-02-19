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

    // Per-level card ordering
    @AppStorage(wrappedValue: Data(), "Analytics.PerLevelCardOrder") var perLevelCardOrderData: Data
    @State var perLevelCardOrder: [PerLevelCardID] = PerLevelCardID.defaultOrder

    // Per-level card visibility
    @AppStorage(wrappedValue: Data(), "Analytics.VisiblePerLevelCards") var visiblePerLevelCardsData: Data
    @State var visiblePerLevelCardSet: Set<PerLevelCardID> = PerLevelCardID.defaultVisible

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
                        .padding(.leading, 12.0)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12.0) {
                            ForEach(visibleSummaryCards, id: \.self) { cardType in
                                cardView(for: cardType)
                                    .frame(width: 130.0)
                                    .cardDraggable(cardType, editing: isEditingCards,
                                                   draggedCard: $draggedCard, cardOrder: $cardOrder,
                                                   onReorder: saveCardOrder)
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
                    .padding(.leading, 12.0)
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
                loadPerLevelCardOrder()
                loadVisiblePerLevelCards()
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

}
// swiftlint:enable type_body_length
