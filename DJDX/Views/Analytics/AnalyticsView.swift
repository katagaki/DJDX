import Charts
import Komponents
import OrderedCollections
import SwiftUI
import UniformTypeIdentifiers

// swiftlint:disable type_body_length
struct AnalyticsView: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Bindable var model: AnalyticsModel

    @AppStorage(wrappedValue: Game.iidxArcade, "Global.SelectedGame") var selectedGame: Game
    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var playTypeToShow: IIDXPlayType
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

    // Collapsed sections
    @AppStorage(wrappedValue: Data(), "Analytics.CollapsedSections") var collapsedSectionsData: Data
    @State var collapsedSections: Set<AnalyticsSection> = []

    // Width of the layout container, measured rather than read from UIScreen.
    @State var containerWidth: CGFloat = 0.0

    var isRegularWidth: Bool { horizontalSizeClass == .regular }

    // Overview grid: 4 columns on iPad, 2 on iPhone.
    var cardColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12.0), count: isRegularWidth ? 4 : 2)
    }

    // Per-level grid: 2 columns on iPad, a single column (vertical list) on iPhone.
    var perLevelColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12.0), count: isRegularWidth ? 2 : 1)
    }

    // Grade/half-width cards take half the standard width on iPad, 60% on iPhone.
    var halfCardWidthRatio: CGFloat { isRegularWidth ? 0.5 : 0.6 }

    // Size summary cards.
    var summaryCardWidth: CGFloat {
        guard containerWidth > 0.0 else { return 130.0 }
        let gridGap = 12.0
        if isRegularWidth {
            let availableWidth = containerWidth - 40.0 - (5.0 * gridGap)
            return availableWidth / 5.0
        }
        let availableWidth = containerWidth - 40.0 - (2.0 * gridGap)
        return (availableWidth / 3.0) + 20.0
    }

    var analyticsNamespace: Namespace.ID
    var towerNamespace: Namespace.ID

    var totalDJLevelCounts: OrderedDictionary<String, Int> {
        let order = Array(IIDXDJLevel.sortedStrings.reversed())
        var totals = OrderedDictionary(uniqueKeys: order, values: order.map { _ in 0 })
        for (_, counts) in model.djLevelPerDifficulty {
            for (level, value) in counts {
                totals[level.rawValue, default: 0] += value
            }
        }
        return totals
    }

    @ViewBuilder
    // swiftlint:disable:next function_body_length
    func overviewCard(for cardType: AnalyticsCardType) -> some View {
        switch cardType {
        case .clearTypeOverall:
            Button {
                if !isEditingCards && model.clearTypePerDifficulty.count > 0 {
                    navigationManager.push(AnalyticsPath.clearTypeOverviewGraph)
                }
            } label: {
                AnalyticsCardView(cardType: .clearTypeOverall, showsHeader: false) {
                    OverviewClearTypeOverallGraph(graphData: .constant(model.clearTypePerDifficulty),
                                                  isHorizontal: true)
                        .chartLegend(.hidden)
                        .chartXAxis(.hidden)
                }
                .perLevelCaption("Analytics.ClearType.Overall")
            }
            .buttonStyle(AnalyticsCardButtonStyle())
            .automaticMatchedTransitionSource(id: "ClearType.Overall", in: analyticsNamespace)
        case .gradeBreakdown:
            Button {
                if !isEditingCards && !model.djLevelPerDifficulty.isEmpty {
                    navigationManager.push(AnalyticsPath.gradeBreakdownDetail)
                }
            } label: {
                AnalyticsCardView(cardType: .gradeBreakdown, showsHeader: false) {
                    let counts = totalDJLevelCounts.elements.filter { $0.value > 0 }
                    Chart(counts, id: \.key) { element in
                        BarMark(
                            x: .value("Shared.ClearCount", element.value),
                            y: .value("Shared.IIDX.DJLevel", element.key)
                        )
                        .foregroundStyle(IIDXDJLevel.color(for: element.key))
                    }
                    .chartXAxis { AxisMarks { AxisGridLine() } }
                    .chartYScale(domain: counts.map(\.key))
                }
                .perLevelCaption("Analytics.DJLevel.Overall")
            }
            .buttonStyle(AnalyticsCardButtonStyle())
            .automaticMatchedTransitionSource(id: "DJLevel.Overall", in: analyticsNamespace)
        case .towerRecent, .towerTotals:
            let transitionID = cardType == .towerRecent ? "Tower.Recent" : "Tower.Totals"
            let caption: LocalizedStringKey = cardType == .towerRecent
                ? "Tower.ChartMode.Recent" : "Shared.IIDX.Tower"
            Button {
                if !isEditingCards {
                    navigationManager.push(cardType == .towerRecent ? TowerPath.recent : TowerPath.totals)
                }
            } label: {
                AnalyticsCardView(cardType: cardType, showsHeader: false) {
                    Group {
                        if cardType == .towerRecent {
                            TowerBarChart(entries: model.towerChartEntries, usesDateAxis: false)
                                .chartXAxis { AxisMarks { AxisGridLine() } }
                                .chartYAxis { AxisMarks { AxisGridLine() } }
                        } else {
                            TowerTotalsChart(
                                totalKeyCount: model.towerTotalKeyCount,
                                totalScratchCount: model.towerTotalScratchCount,
                                showsAnnotations: true
                            )
                            .chartXAxis { AxisMarks { AxisGridLine() } }
                            .chartYAxis { AxisMarks { AxisGridLine() } }
                        }
                    }
                    .opacity(model.towerEntries.isEmpty ? 0.25 : 1.0)
                    .overlay {
                        if model.towerEntries.isEmpty {
                            Text("Shared.NoData")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .perLevelCaption(caption)
            }
            .buttonStyle(AnalyticsCardButtonStyle())
            .automaticMatchedTransitionSource(id: transitionID, in: towerNamespace)
        default:
            EmptyView()
        }
    }

    var isEditingCards: Bool { isEditing }

    func toggleCard(_ cardType: AnalyticsCardType) {
        withAnimation(.smooth.speed(2.0)) {
            if visibleCards.contains(cardType) {
                visibleCards.remove(cardType)
            } else {
                visibleCards.insert(cardType)
            }
            saveVisibleCards()
        }
    }

    func togglePerLevelCard(_ card: PerLevelCardID) {
        withAnimation(.smooth.speed(2.0)) {
            if visiblePerLevelCardSet.contains(card) {
                visiblePerLevelCardSet.remove(card)
            } else {
                visiblePerLevelCardSet.insert(card)
            }
            saveVisiblePerLevelCards()
        }
    }

    var body: some View {
        VStack(spacing: 20.0) {
                // MARK: Overview section
                let overviewCards = cardOrder.filter {
                    $0 == .clearTypeOverall || $0 == .gradeBreakdown ||
                    (selectedGame.supportsTower && $0.isTowerCard)
                }
                let shownOverviewCards = isEditing ? overviewCards : overviewCards.filter { visibleCards.contains($0) }
                if !shownOverviewCards.isEmpty {
                    VStack(spacing: 12.0) {
                        AnalyticsSectionHeader(
                            title: AnalyticsSection.overview.titleKey,
                            isCollapsible: !isEditing,
                            isExpanded: isSectionExpanded(.overview)
                        ) {
                            toggleSection(.overview)
                        }
                        if isSectionExpanded(.overview) {
                            LazyVGrid(columns: cardColumns, spacing: 12.0) {
                                ForEach(shownOverviewCards, id: \.self) { cardType in
                                    overviewCard(for: cardType)
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
                }

                // MARK: Last Play section
                let summaryCards = cardOrder.filter { $0.isSummaryCard }
                let shownSummaryCards = isEditing ? summaryCards : summaryCards.filter { visibleCards.contains($0) }
                if !shownSummaryCards.isEmpty {
                    VStack(spacing: 12.0) {
                        AnalyticsSectionHeader(
                            title: AnalyticsSection.lastPlay.titleKey,
                            isCollapsible: !isEditing,
                            isExpanded: isSectionExpanded(.lastPlay)
                        ) {
                            toggleSection(.lastPlay)
                        }
                        if isSectionExpanded(.lastPlay) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12.0) {
                                    ForEach(shownSummaryCards, id: \.self) { cardType in
                                        cardView(for: cardType)
                                            .frame(width: cardType.isGradeCard
                                                   ? summaryCardWidth * halfCardWidthRatio : summaryCardWidth)
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
                    }
                }

                // MARK: Per-level section
                let shownPerLevelCards = isEditing ? perLevelCardOrder : visiblePerLevelCards
                if !shownPerLevelCards.isEmpty {
                    VStack(spacing: 12.0) {
                        AnalyticsSectionHeader(
                            title: AnalyticsSection.perLevel.titleKey,
                            isCollapsible: !isEditing,
                            isExpanded: isSectionExpanded(.perLevel)
                        ) {
                            toggleSection(.perLevel)
                        }
                        if isSectionExpanded(.perLevel) {
                            LazyVGrid(columns: perLevelColumns, spacing: 12.0) {
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
                        }
                    }
                }
            }
            .padding(.top, 20.0)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                containerWidth = newWidth
            }
            .task {
                loadCardOrder()
                loadVisibleCards()
                loadPerLevelCardOrder()
                loadVisiblePerLevelCards()
                loadCollapsedSections()
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
            .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
                Task { await reload() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .analyticsLayoutReset)) { _ in
                withAnimation(.smooth.speed(2.0)) {
                    isEditing = false
                    cardOrder = AnalyticsCardType.defaultOrder
                    visibleCards = AnalyticsCardType.defaultVisible
                    perLevelCardOrder = PerLevelCardID.defaultOrder
                    visiblePerLevelCardSet = PerLevelCardID.defaultVisible
                    collapsedSections = []
                }
                saveCollapsedSections()
            }
    }

    func reload() async {
        await model.reload(playType: playTypeToShow, iidxVersion: iidxVersion)
    }

}
// swiftlint:enable type_body_length
