//
//  AnalyticsView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import Charts
import Komponents
import OrderedCollections
import SwiftUI
import UniformTypeIdentifiers

// swiftlint:disable type_body_length
struct AnalyticsView: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @Bindable var model: AnalyticsModel

    @AppStorage(wrappedValue: Game.iidxArcade, "Global.SelectedGame") var selectedGame: Game
    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var playTypeToShow: IIDXPlayType
    @AppStorage(wrappedValue: 1, "Analytics.Overview.ClearType.Level") var levelFilterForOverviewClearType: Int
    @AppStorage(wrappedValue: 1, "Analytics.Overview.ScoreRate.Level") var levelFilterForOverviewScoreRate: Int
    @AppStorage(wrappedValue: 1, "Analytics.Trends.ClearType.Level") var levelFilterForTrendsClearType: Int
    @AppStorage(wrappedValue: 1, "Analytics.Trends.DJLevel.Level") var levelFilterForTrendsDJLevel: Int
    @AppStorage(wrappedValue: IIDXVersion.sparkleShower, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    // Card ordering
    @AppStorage(wrappedValue: Data(), "Analytics.CardOrder") var cardOrderData: Data
    @State var cardOrder: [AnalyticsCardType] = AnalyticsCardType.defaultOrder
    @State var editingSection: AnalyticsSection?

    var isEditingCards: Bool { editingSection != nil }

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

    let cardColumns = [
        GridItem(.flexible(), spacing: 12.0),
        GridItem(.flexible(), spacing: 12.0)
    ]

    var analyticsNamespace: Namespace.ID
    var towerNamespace: Namespace.ID

    @ViewBuilder
    func towerCardButton(for cardType: AnalyticsCardType) -> some View {
        let transitionID = cardType == .towerRecent ? "Tower.Recent" : "Tower.Totals"
        Button {
            if !isEditingCards {
                navigationManager.push(cardType == .towerRecent ? TowerPath.recent : TowerPath.totals)
            }
        } label: {
            AnalyticsCardView(cardType: cardType) {
                switch cardType {
                case .towerRecent:
                    TowerBarChart(entries: model.towerChartEntries, usesDateAxis: false)
                        .chartXAxis { AxisMarks { AxisGridLine() } }
                        .chartYAxis { AxisMarks { AxisGridLine() } }
                case .towerTotals:
                    TowerTotalsChart(
                        totalKeyCount: model.towerTotalKeyCount,
                        totalScratchCount: model.towerTotalScratchCount,
                        showsAnnotations: false
                    )
                    .chartXAxis { AxisMarks { AxisGridLine() } }
                    .chartYAxis { AxisMarks { AxisGridLine() } }
                default:
                    EmptyView()
                }
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: transitionID, in: towerNamespace)
    }

    func toggleEdit(_ section: AnalyticsSection) {
        withAnimation(.snappy) {
            if editingSection == section {
                editingSection = nil
            } else {
                editingSection = section
            }
            draggedCard = nil
            draggedPerLevelCard = nil
        }
    }

    func toggleCard(_ cardType: AnalyticsCardType) {
        withAnimation(.snappy) {
            if visibleCards.contains(cardType) {
                visibleCards.remove(cardType)
            } else {
                visibleCards.insert(cardType)
            }
            saveVisibleCards()
        }
    }

    func togglePerLevelCard(_ card: PerLevelCardID) {
        withAnimation(.snappy) {
            if visiblePerLevelCardSet.contains(card) {
                visiblePerLevelCardSet.remove(card)
            } else {
                visiblePerLevelCardSet.insert(card)
            }
            saveVisiblePerLevelCards()
        }
    }

    var body: some View {
        VStack(spacing: 0.0) {
                // MARK: Overview section
                AnalyticsSectionHeader(
                    title: AnalyticsSection.overview.titleKey,
                    isEditing: editingSection == .overview
                ) {
                    toggleEdit(.overview)
                }
                if editingSection == .overview || visibleCards.contains(.clearTypeOverall) {
                    clearTypeOverallCard
                        .editableCard(isVisible: visibleCards.contains(.clearTypeOverall),
                                      isEditing: editingSection == .overview,
                                      seed: 0) {
                            toggleCard(.clearTypeOverall)
                        }
                        .padding(.horizontal)
                }

                // Tower cards (half width, IIDX AC only)
                let towerCards = selectedGame.supportsTower ? cardOrder.filter { $0.isTowerCard } : []
                let shownTowerCards = editingSection == .overview
                    ? towerCards
                    : towerCards.filter { visibleCards.contains($0) }
                if !shownTowerCards.isEmpty {
                    LazyVGrid(columns: cardColumns, spacing: 12.0) {
                        ForEach(shownTowerCards, id: \.self) { cardType in
                            towerCardButton(for: cardType)
                                .editableCard(isVisible: visibleCards.contains(cardType),
                                              isEditing: editingSection == .overview,
                                              seed: cardOrder.firstIndex(of: cardType) ?? 0) {
                                    toggleCard(cardType)
                                }
                                .cardDraggable(cardType, editing: editingSection == .overview,
                                               draggedCard: $draggedCard, cardOrder: $cardOrder,
                                               onReorder: saveCardOrder)
                        }
                    }
                    .padding([.horizontal, .top])
                }

                // MARK: Last Play section
                AnalyticsSectionHeader(
                    title: AnalyticsSection.lastPlay.titleKey,
                    isEditing: editingSection == .lastPlay
                ) {
                    toggleEdit(.lastPlay)
                }
                let summaryCards = cardOrder.filter { $0.isSummaryCard }
                let shownSummaryCards = editingSection == .lastPlay
                    ? summaryCards
                    : summaryCards.filter { visibleCards.contains($0) }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12.0) {
                        ForEach(shownSummaryCards, id: \.self) { cardType in
                            cardView(for: cardType)
                                .frame(width: 130.0)
                                .editableCard(isVisible: visibleCards.contains(cardType),
                                              isEditing: editingSection == .lastPlay,
                                              seed: cardOrder.firstIndex(of: cardType) ?? 0) {
                                    toggleCard(cardType)
                                }
                                .cardDraggable(cardType, editing: editingSection == .lastPlay,
                                               draggedCard: $draggedCard, cardOrder: $cardOrder,
                                               onReorder: saveCardOrder)
                        }
                    }
                    .padding(.horizontal)
                }

                // MARK: Per-level section
                AnalyticsSectionHeader(
                    title: AnalyticsSection.perLevel.titleKey,
                    isEditing: editingSection == .perLevel
                ) {
                    toggleEdit(.perLevel)
                }
                let shownPerLevelCards = editingSection == .perLevel ? perLevelCardOrder : visiblePerLevelCards
                LazyVGrid(columns: cardColumns, spacing: 12.0) {
                    ForEach(shownPerLevelCards, id: \.self) { card in
                        perLevelCard(difficulty: card.difficulty, category: card.category)
                            .editableCard(
                                isVisible: visiblePerLevelCardSet.contains(card),
                                isEditing: editingSection == .perLevel,
                                seed: card.difficulty * 10 +
                                    (AnalyticsPerLevelCategory.allCases.firstIndex(of: card.category) ?? 0)
                            ) {
                                togglePerLevelCard(card)
                            }
                            .perLevelCardDraggable(card, editing: editingSection == .perLevel,
                                                   draggedCard: $draggedPerLevelCard,
                                                   cardOrder: $perLevelCardOrder,
                                                   onReorder: savePerLevelCardOrder)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16.0)
            }
            .task {
                loadCardOrder()
                loadVisibleCards()
                loadPerLevelCardOrder()
                loadVisiblePerLevelCards()
                if model.dataState == .initializing {
                    await reload()
                }
            }
            .onChange(of: playTypeToShow) { _, _ in
                Task {
                    await reload()
                    debugPrint("Reloaded on change of play type")
                }
            }
            .onChange(of: iidxVersion) { _, _ in
                Task {
                    await reload()
                    debugPrint("Reloaded on change of version")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dataMigrationCompleted)) { _ in
                Task { await reload() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
                Task { await reload() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .analyticsLayoutReset)) { _ in
                withAnimation(.snappy) {
                    editingSection = nil
                    cardOrder = AnalyticsCardType.defaultOrder
                    visibleCards = AnalyticsCardType.defaultVisible
                    perLevelCardOrder = PerLevelCardID.defaultOrder
                    visiblePerLevelCardSet = PerLevelCardID.defaultVisible
                }
            }
    }

    func reload() async {
        await model.reload(playType: playTypeToShow, iidxVersion: iidxVersion)
    }

}
// swiftlint:enable type_body_length
