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

    @State var isShowingSettings: Bool = false

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
                    TowerBarChart(entries: model.towerChartEntries)
                        .chartLegend(.hidden)
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                case .towerTotals:
                    TowerTotalsChart(
                        totalKeyCount: model.towerTotalKeyCount,
                        totalScratchCount: model.towerTotalScratchCount
                    )
                    .chartLegend(.hidden)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                default:
                    EmptyView()
                }
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: transitionID, in: towerNamespace)
    }

    @ViewBuilder
    var editControls: some View {
        if isEditingCards {
            Button {
                withAnimation(.snappy) {
                    isEditingCards = false
                    draggedCard = nil
                    draggedPerLevelCard = nil
                }
            } label: {
                Label(.sharedDone, systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        } else if model.dataState == .initializing || model.dataState == .loading {
            ProgressView()
                .progressViewStyle(.circular)
                .frame(maxWidth: .infinity)
        } else {
            HStack(spacing: 12.0) {
                Button {
                    withAnimation(.snappy) { isEditingCards = true }
                } label: {
                    Label("Analytics.Settings.EditCards", systemImage: "arrow.up.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button {
                    isShowingSettings = true
                } label: {
                    Label("Shared.Edit", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0.0) {
                // Overall summary (position fixed)
                clearTypeOverallCard
                    .padding(.horizontal)
                    .padding(.top, 8.0)

                // Tower cards (half width, IIDX AC only)
                let visibleTowerCards = selectedGame.supportsTower ? cardOrder.filter {
                    $0.isTowerCard && visibleCards.contains($0)
                } : []
                if !visibleTowerCards.isEmpty {
                    LazyVGrid(columns: cardColumns, spacing: 12.0) {
                        ForEach(visibleTowerCards, id: \.self) { cardType in
                            towerCardButton(for: cardType)
                                .cardDraggable(cardType, editing: isEditingCards,
                                               draggedCard: $draggedCard, cardOrder: $cardOrder,
                                               onReorder: saveCardOrder)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8.0)
                }

                // Summary cards - horizontal scroll
                let visibleSummaryCards = cardOrder.filter {
                    $0.isSummaryCard && visibleCards.contains($0)
                }
                if !visibleSummaryCards.isEmpty {
                    Text("Analytics.Header.NewScores")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .padding(.top, 20.0)
                        .padding(.bottom, 4.0)
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
                    .padding(.top, 20.0)
                    .padding(.bottom, 4.0)
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

                editControls
                    .padding(.horizontal)
                    .padding(.bottom, 16.0)
            }
            .sheet(isPresented: $isShowingSettings) {
                AnalyticsSettingsSheet(
                    visibleCards: $visibleCards,
                    cardOrder: $cardOrder,
                    visiblePerLevelCardSet: $visiblePerLevelCardSet,
                    perLevelCardOrder: $perLevelCardOrder,
                    onSaveVisibleCards: saveVisibleCards,
                    onSaveVisiblePerLevelCards: saveVisiblePerLevelCards,
                    onSaveCardOrder: saveCardOrder,
                    onSavePerLevelCardOrder: savePerLevelCardOrder,
                    showsTowerCards: selectedGame.supportsTower
                )
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
            .onReceive(NotificationCenter.default.publisher(for: .dataMigrationCompleted)) { _ in
                Task { await reload() }
            }
    }

    func reload() async {
        await model.reload(playType: playTypeToShow, iidxVersion: iidxVersion)
    }

}
// swiftlint:enable type_body_length
