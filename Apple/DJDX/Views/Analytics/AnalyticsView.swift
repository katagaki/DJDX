import Charts
import Komponents
import OrderedCollections
import SwiftUI
import UniformTypeIdentifiers

struct AnalyticsView: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Bindable var model: AnalyticsModel

    @AppStorage(wrappedValue: Game.iidxArcade, "Global.SelectedGame") var selectedGame: Game
    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var playTypeToShow: IIDXPlayType
    @AppStorage(wrappedValue: IIDXVersion.zinrai, "Global.IIDX.Version") var iidxVersion: IIDXVersion
    @AppStorage var isShowingOnlyPlayDataWithScores: Bool
    @AppStorage var difficultiesToShow: Set<IIDXDifficulty>
    @AppStorage var levelsToShow: Set<IIDXLevel>
    @AppStorage var clearTypesToShow: Set<IIDXClearType>
    @AppStorage var djLevelsToShow: Set<IIDXDJLevel>
    @AppStorage var versionsToShow: Set<String>

    // Card ordering
    @AppStorage(wrappedValue: Data(), "Analytics.CardOrder") var cardOrderData: Data
    @AppStorage(wrappedValue: [], "Analytics.ClearType.Overall.CardLevels") var clearTypeCardLevels: Set<String>
    @AppStorage(wrappedValue: [], "Analytics.DJLevel.Overall.CardLevels") var djLevelCardLevels: Set<String>
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
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.overviewKey) var isOverviewVisible: Bool
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.lastPlayKey) var isLastPlayVisible: Bool
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.perLevelKey) var isPerLevelVisible: Bool

    // Width of the layout container, measured rather than read from UIScreen.

    var isRegularWidth: Bool { horizontalSizeClass == .regular }

    var cardColumnCount: Int { isRegularWidth ? 4 : 2 }

    var perLevelColumnCount: Int { isRegularWidth ? 2 : 1 }

    var analyticsNamespace: Namespace.ID
    var towerNamespace: Namespace.ID

    init(model: AnalyticsModel, isEditing: Binding<Bool>,
         analyticsNamespace: Namespace.ID, towerNamespace: Namespace.ID) {
        self.model = model
        self._isEditing = isEditing
        self.analyticsNamespace = analyticsNamespace
        self.towerNamespace = towerNamespace
        let filterKeyPrefix = Game.stored.iidxFilterKeyPrefix
        self._isShowingOnlyPlayDataWithScores = AppStorage(
            wrappedValue: true, "\(filterKeyPrefix).ScoreAvailableOnlyFilter"
        )
        self._difficultiesToShow = AppStorage(wrappedValue: [], "\(filterKeyPrefix).DifficultyFilters")
        self._levelsToShow = AppStorage(wrappedValue: [], "\(filterKeyPrefix).LevelFilters")
        self._clearTypesToShow = AppStorage(wrappedValue: [], "\(filterKeyPrefix).ClearTypeFilters")
        self._djLevelsToShow = AppStorage(wrappedValue: [], "\(filterKeyPrefix).DJLevelFilters")
        self._versionsToShow = AppStorage(wrappedValue: [], "\(filterKeyPrefix).VersionFilters")
    }

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
                                                  isHorizontal: true,
                                                  levelLimit: 3,
                                                  shownLevels: Set(clearTypeCardLevels.compactMap(Int.init)))
                        .chartLegend(.hidden)
                        .chartXAxis(.hidden)
                }
                .perLevelCaption("Analytics.ClearType.Overall")
            }
            .buttonStyle(AnalyticsCardButtonStyle())
            .matchedTransitionSource(id: "ClearType.Overall", in: analyticsNamespace)
        case .gradeBreakdown:
            Button {
                if !isEditingCards && !model.djLevelPerDifficulty.isEmpty {
                    navigationManager.push(AnalyticsPath.gradeBreakdownDetail)
                }
            } label: {
                AnalyticsCardView(cardType: .gradeBreakdown, showsHeader: false) {
                    let counts = djLevelCardLevels.isEmpty
                        ? Array(totalDJLevelCounts.elements.filter { $0.value > 0 }.prefix(3))
                        : totalDJLevelCounts.elements.filter { djLevelCardLevels.contains($0.key) }
                    HStack(spacing: 6.0) {
                        VStack(alignment: .trailing, spacing: 0.0) {
                            ForEach(counts, id: \.key) { element in
                                IIDXMetallicText.djLevel(element.key)
                                    .font(.caption2)
                                    .fixedSize()
                                    .frame(maxHeight: .infinity)
                            }
                        }
                        Chart(counts, id: \.key) { element in
                            BarMark(
                                x: .value("Shared.ClearCount", element.value),
                                y: .value("Shared.IIDX.DJLevel", element.key)
                            )
                            .foregroundStyle(IIDXDJLevel.color(for: element.key))
                            .cornerRadius(0.0)
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .chartYScale(domain: counts.map(\.key))
                    }
                }
                .perLevelCaption("Analytics.DJLevel.Overall")
            }
            .buttonStyle(AnalyticsCardButtonStyle())
            .matchedTransitionSource(id: "DJLevel.Overall", in: analyticsNamespace)
        case .progressTrend, .scoreProgressTrend:
            progressCard(cardType == .progressTrend ? .clears : .highScores)
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
                                .chartXAxis(.hidden)
                                .chartYAxis(.hidden)
                        } else {
                            TowerTotalsChart(
                                totalKeyCount: model.towerTotalKeyCount,
                                totalScratchCount: model.towerTotalScratchCount,
                                showsAnnotations: !model.towerEntries.isEmpty
                            )
                            .chartXAxis(.hidden)
                            .chartYAxis(.hidden)
                            .padding(.top, 6.0)
                        }
                    }
                    .opacity(model.towerEntries.isEmpty ? 0.25 : 1.0)
                    .overlay {
                        if model.towerEntries.isEmpty {
                            Text("Shared.NoData")
                                .emptyLabel()
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .perLevelCaption(caption)
            }
            .buttonStyle(AnalyticsCardButtonStyle())
            .matchedTransitionSource(id: transitionID, in: towerNamespace)
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
        let overviewCards = cardOrder.filter {
            $0.isOverviewCard && (selectedGame.supportsTower || !$0.isTowerCard)
        }
        let shownOverviewCards = isOverviewVisible
            ? (isEditing ? overviewCards : overviewCards.filter { visibleCards.contains($0) })
            : []
        let summaryCards = cardOrder.filter { $0.isSummaryCard }
        let shownSummaryCards = isLastPlayVisible
            ? (isEditing ? summaryCards : summaryCards.filter {
                visibleCards.contains($0) && summaryCount(for: $0) > 0
            })
            : []
        let shownPerLevelCards = isPerLevelVisible
            ? (isEditing ? perLevelCardOrder : visiblePerLevelCards)
            : []
        let hasVisibleSection = !shownOverviewCards.isEmpty || !shownSummaryCards.isEmpty || !shownPerLevelCards.isEmpty
        VStack(spacing: DesignMetrics.sectionGap) {
                // MARK: Overview section
                if !shownOverviewCards.isEmpty {
                    VStack(spacing: DesignMetrics.gap) {
                        AnalyticsSectionHeader(
                            title: AnalyticsSection.overview.titleKey,
                            isCollapsible: !isEditing,
                            isExpanded: isSectionExpanded(.overview)
                        ) {
                            toggleSection(.overview)
                        }
                        if isSectionExpanded(.overview) {
                            AnalyticsCardGrid(items: shownOverviewCards, columns: cardColumnCount, spacing: DesignMetrics.gap) { cardType in
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
                            .padding(.horizontal)
                        }
                    }
                }

                // MARK: Last Play section
                if !shownSummaryCards.isEmpty {
                    VStack(spacing: DesignMetrics.gap) {
                        AnalyticsSectionHeader(
                            title: AnalyticsSection.lastPlay.titleKey,
                            isCollapsible: !isEditing,
                            isExpanded: isSectionExpanded(.lastPlay)
                        ) {
                            toggleSection(.lastPlay)
                        }
                        if isSectionExpanded(.lastPlay) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DesignMetrics.gap) {
                                    ForEach(shownSummaryCards, id: \.self) { cardType in
                                        cardView(for: cardType)
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
                if !shownPerLevelCards.isEmpty {
                    VStack(spacing: DesignMetrics.gap) {
                        AnalyticsSectionHeader(
                            title: AnalyticsSection.perLevel.titleKey,
                            isCollapsible: !isEditing,
                            isExpanded: isSectionExpanded(.perLevel)
                        ) {
                            toggleSection(.perLevel)
                        }
                        if isSectionExpanded(.perLevel) {
                            AnalyticsCardGrid(items: shownPerLevelCards, columns: perLevelColumnCount, spacing: DesignMetrics.gap) { card in
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
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.top, hasVisibleSection ? DesignMetrics.topPadding : 0.0)
            .task {
                loadVisibleCards()
                loadCardOrder()
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
            .onChange(of: selectedGame) { _, _ in
                Task { await reload() }
            }
            .onChange(of: filters) { _, _ in
                if model.sessionStore == nil {
                    Task { await reload() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
                Task { await reload() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .playSessionDidChange)
                .debounce(for: .seconds(0.4), scheduler: RunLoop.main)) { _ in
                if model.sessionStore != nil {
                    Task { await reload() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .capturedPlayDidChange)
                .debounce(for: .seconds(0.4), scheduler: RunLoop.main)) { _ in
                if model.sessionStore != nil {
                    Task { await reload() }
                }
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

    var filters: FilterOptions {
        FilterOptions(playType: playTypeToShow,
                      onlyPlayDataWithScores: isShowingOnlyPlayDataWithScores,
                      levels: levelsToShow,
                      difficulties: difficultiesToShow,
                      clearTypes: clearTypesToShow,
                      djLevels: djLevelsToShow,
                      versions: versionsToShow)
    }

    func reload() async {
        await model.reload(playType: playTypeToShow, iidxVersion: iidxVersion, filters: filters)
    }
}
