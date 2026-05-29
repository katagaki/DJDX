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
    @Binding var isEditing: Bool

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

    var isEditingCards: Bool { isEditing }

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
                let towerCards = selectedGame.supportsTower ? cardOrder.filter { $0.isTowerCard } : []
                let shownTowerCards = isEditing ? towerCards : towerCards.filter { visibleCards.contains($0) }
                let isClearLampShown = isEditing || visibleCards.contains(.clearTypeOverall)
                if isEditing || isClearLampShown || !shownTowerCards.isEmpty {
                    AnalyticsSectionHeader(title: AnalyticsSection.overview.titleKey)
                    if isClearLampShown {
                        clearTypeOverallCard
                            .editableCard(isVisible: visibleCards.contains(.clearTypeOverall),
                                          isEditing: isEditing,
                                          seed: 0) {
                                toggleCard(.clearTypeOverall)
                            }
                            .padding(.horizontal)
                    }
                    if !shownTowerCards.isEmpty {
                        LazyVGrid(columns: cardColumns, spacing: 12.0) {
                            ForEach(shownTowerCards, id: \.self) { cardType in
                                towerCardButton(for: cardType)
                                    .editableCard(isVisible: visibleCards.contains(cardType),
                                                  isEditing: isEditing,
                                                  seed: cardOrder.firstIndex(of: cardType) ?? 0) {
                                        toggleCard(cardType)
                                    }
                                    .cardDraggable(cardType, editing: isEditing,
                                                   draggedCard: $draggedCard, cardOrder: $cardOrder,
                                                   onReorder: saveCardOrder)
                            }
                        }
                        .padding([.horizontal, .top])
                    }
                }

                // MARK: Last Play section
                let summaryCards = cardOrder.filter { $0.isSummaryCard }
                let shownSummaryCards = isEditing ? summaryCards : summaryCards.filter { visibleCards.contains($0) }
                if !shownSummaryCards.isEmpty {
                    AnalyticsSectionHeader(title: AnalyticsSection.lastPlay.titleKey)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12.0) {
                            ForEach(shownSummaryCards, id: \.self) { cardType in
                                cardView(for: cardType)
                                    .frame(width: 130.0)
                                    .editableCard(isVisible: visibleCards.contains(cardType),
                                                  isEditing: isEditing,
                                                  seed: cardOrder.firstIndex(of: cardType) ?? 0) {
                                        toggleCard(cardType)
                                    }
                                    .cardDraggable(cardType, editing: isEditing,
                                                   draggedCard: $draggedCard, cardOrder: $cardOrder,
                                                   onReorder: saveCardOrder)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // MARK: Per-level section
                let shownPerLevelCards = isEditing ? perLevelCardOrder : visiblePerLevelCards
                if !shownPerLevelCards.isEmpty {
                    AnalyticsSectionHeader(title: AnalyticsSection.perLevel.titleKey)
                    LazyVGrid(columns: cardColumns, spacing: 12.0) {
                        ForEach(shownPerLevelCards, id: \.self) { card in
                            perLevelCard(difficulty: card.difficulty, category: card.category)
                                .editableCard(
                                    isVisible: visiblePerLevelCardSet.contains(card),
                                    isEditing: isEditing,
                                    seed: card.difficulty * 10 +
                                        (AnalyticsPerLevelCategory.allCases.firstIndex(of: card.category) ?? 0)
                                ) {
                                    togglePerLevelCard(card)
                                }
                                .perLevelCardDraggable(card, editing: isEditing,
                                                       draggedCard: $draggedPerLevelCard,
                                                       cardOrder: $perLevelCardOrder,
                                                       onReorder: savePerLevelCardOrder)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16.0)
                }
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
                    isEditing = false
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
