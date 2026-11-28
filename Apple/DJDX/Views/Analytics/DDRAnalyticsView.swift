import Charts
import OrderedCollections
import SwiftUI

struct DDRAnalyticsView: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @Bindable var model: DDRAnalyticsModel

    @AppStorage(wrappedValue: DDRVersion.world, "Global.DDR.Version") var ddrVersion: DDRVersion
    @AppStorage(wrappedValue: DDRPlayStyle.single, "Global.DDR.Style") var ddrStyleToShow: DDRPlayStyle
    @AppStorage(wrappedValue: true, "DDRScoresView.ScoreAvailableOnlyFilter") var isShowingOnlyPlayedCharts: Bool
    @AppStorage(wrappedValue: [], "DDRScoresView.DifficultyFilters") var difficultiesToShow: Set<DDRDifficulty>
    @AppStorage(wrappedValue: [], "DDRScoresView.LevelFilters") var levelsToShow: Set<Int>
    @AppStorage(wrappedValue: [], "DDRScoresView.ClearLampFilters") var clearLampsToShow: Set<String>
    @AppStorage(wrappedValue: [], "DDRScoresView.RankFilters") var ranksToShow: Set<String>

    @Binding var isEditing: Bool

    var analyticsNamespace: Namespace.ID

    @AppStorage(wrappedValue: Data(), "Analytics.DDR.CardOrder") var cardOrderData: Data
    @State var cardOrder: [DDRAnalyticsCard] = DDRAnalyticsCard.defaultOrder
    @State var draggedCard: DDRAnalyticsCard?

    @AppStorage(wrappedValue: Data(), "Analytics.DDR.VisibleCards") var visibleCardsData: Data
    @State var visibleCards: Set<DDRAnalyticsCard> = DDRAnalyticsCard.defaultVisible

    @AppStorage(wrappedValue: false, "Analytics.DDR.OverviewCollapsed") var isOverviewCollapsedStored: Bool
    @State var isOverviewCollapsed: Bool = false
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.overviewKey) var isOverviewVisible: Bool

    let cardColumns = [
        GridItem(.flexible(), spacing: DesignMetrics.gap),
        GridItem(.flexible(), spacing: DesignMetrics.gap)
    ]

    var body: some View {
        VStack(spacing: DesignMetrics.sectionGap) {
            if isOverviewVisible {
                overviewSection
            }
        }
        .padding(.top, isOverviewVisible ? DesignMetrics.topPadding : 0.0)
        .onAppear {
            loadCardOrder()
            loadVisibleCards()
            isOverviewCollapsed = isOverviewCollapsedStored
        }
        .task {
            if model.dataState == .initializing {
                await reload()
            }
        }
        .onChange(of: ddrVersion) { _, _ in
            Task { await reload() }
        }
        .onChange(of: ddrStyleToShow) { _, _ in
            Task { await reload() }
        }
        .onChange(of: filters) { _, _ in
            Task { await reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await reload() }
        }
    }

    var filters: DDRFilterOptions {
        DDRFilterOptions(onlyPlayedCharts: isShowingOnlyPlayedCharts,
                         difficulties: difficultiesToShow,
                         levels: levelsToShow,
                         clearLamps: clearLampsToShow,
                         ranks: ranksToShow)
    }

    func reload() async {
        await model.reload(version: ddrVersion, style: ddrStyleToShow, filters: filters)
    }

    // MARK: - Sections

    @ViewBuilder
    var overviewSection: some View {
        let overviewCards = cardOrder.filter { $0.section == .overview }
        let shownCards = isEditing ? overviewCards : overviewCards.filter { visibleCards.contains($0) }
        if !shownCards.isEmpty {
            let isExpanded = isEditing || !isOverviewCollapsed
            VStack(spacing: DesignMetrics.gap) {
                AnalyticsSectionHeader(
                    title: AnalyticsSection.overview.titleKey,
                    isCollapsible: !isEditing,
                    isExpanded: isExpanded
                ) {
                    withAnimation(.smooth.speed(2.0)) { isOverviewCollapsed.toggle() }
                    isOverviewCollapsedStored = isOverviewCollapsed
                }
                if isExpanded {
                    AnalyticsCardGrid(items: shownCards, columns: 2, spacing: DesignMetrics.gap) { cardType in
                        overviewCardView(for: cardType)
                            .editableCard(isVisible: visibleCards.contains(cardType),
                                          isEditing: isEditing,
                                          seed: cardOrder.firstIndex(of: cardType) ?? 0) {
                                toggleCard(cardType)
                            }
                            .ddrCardDraggable(cardType, editing: isEditing,
                                              draggedCard: $draggedCard, cardOrder: $cardOrder,
                                              onReorder: saveCardOrder)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Cards

    @ViewBuilder
    func overviewCardView(for cardType: DDRAnalyticsCard) -> some View {
        Button {
            if !isEditing, let destination = cardType.destination {
                navigationManager.push(destination)
            }
        } label: {
            switch cardType {
            case .clearBreakdown: clearBreakdownCard
            case .rankBreakdown: rankBreakdownCard
            case .flareSkillTrend: flareSkillTrendCard
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .matchedTransitionSource(id: cardType.transitionID, in: analyticsNamespace)
    }

    // MARK: - Card storage

    func loadCardOrder() {
        if let decoded = try? JSONDecoder().decode([DDRAnalyticsCard].self, from: cardOrderData),
           !decoded.isEmpty {
            var order = decoded
            for cardType in DDRAnalyticsCard.defaultOrder where !order.contains(cardType) {
                order.append(cardType)
            }
            order.removeAll { !DDRAnalyticsCard.defaultOrder.contains($0) }
            cardOrder = order
        }
    }

    func saveCardOrder() {
        cardOrderData = (try? JSONEncoder().encode(cardOrder)) ?? Data()
    }

    func loadVisibleCards() {
        if let decoded = try? JSONDecoder().decode(Set<DDRAnalyticsCard>.self, from: visibleCardsData) {
            visibleCards = decoded
        }
    }

    func saveVisibleCards() {
        visibleCardsData = (try? JSONEncoder().encode(visibleCards)) ?? Data()
    }

    func toggleCard(_ cardType: DDRAnalyticsCard) {
        withAnimation(.smooth.speed(2.0)) {
            if visibleCards.contains(cardType) {
                visibleCards.remove(cardType)
            } else {
                visibleCards.insert(cardType)
            }
            saveVisibleCards()
        }
    }

    // MARK: - Overview card content

    var totalClearCounts: OrderedDictionary<String, Int> {
        var totals: OrderedDictionary<String, Int> = OrderedDictionary(
            uniqueKeys: DDRSongRecord.clearBreakdownOrder,
            values: DDRSongRecord.clearBreakdownOrder.map { _ in 0 }
        )
        for (_, counts) in model.clearTypePerDifficulty {
            for (key, value) in counts {
                totals[key, default: 0] += value
            }
        }
        return totals
    }

    var totalRankCounts: OrderedDictionary<String, Int> {
        var totals: OrderedDictionary<String, Int> = OrderedDictionary(
            uniqueKeys: DDRSongRecord.rankOrder,
            values: DDRSongRecord.rankOrder.map { _ in 0 }
        )
        for (_, counts) in model.rankPerDifficulty {
            for (key, value) in counts {
                totals[key, default: 0] += value
            }
        }
        return totals
    }

    var flareSkillTrendCard: some View {
        AnalyticsCardView(title: "Analytics.DDR.FlareSkillTrend",
                          systemImage: "",
                          iconColor: .clear,
                          contentHeight: 160.0,
                          showsHeader: false) {
            TrendCardContent(points: model.flareSkillHistory, color: .orange,
                             format: DDRAnalyticsModel.formatFlareSkill)
        }
        .perLevelCaption("Analytics.DDR.FlareSkillTrend")
    }

    func clearLabel(_ key: String) -> String {
        key == DDRSongRecord.noClearKey ? "NO CLEAR" : key.uppercased()
    }

    var clearBreakdownCard: some View {
        AnalyticsCardView(title: "Analytics.DDR.ClearBreakdown",
                          systemImage: "",
                          iconColor: .clear,
                          contentHeight: 160.0,
                          showsHeader: false) {
            StackedBreakdownBar(items: totalClearCounts.elements.filter { $0.value > 0 }.map { element in
                StackedBreakdownItem(label: clearLabel(element.key), value: element.value,
                                       color: DDRSongRecord.clearColor(for: element.key))
            })
        }
        .perLevelCaption("Analytics.DDR.ClearBreakdown")
    }

    var rankBreakdownCard: some View {
        AnalyticsCardView(title: "Analytics.DDR.RankBreakdown",
                          systemImage: "",
                          iconColor: .clear,
                          contentHeight: 160.0,
                          showsHeader: false) {
            StackedBreakdownBar(items: totalRankCounts.elements.filter { $0.value > 0 }.map { element in
                StackedBreakdownItem(label: DDRSongRecord.rankDisplay(forStem: element.key), value: element.value,
                                       color: DDRSongRecord.rankColor(forStem: element.key))
            })
        }
        .perLevelCaption("Analytics.DDR.RankBreakdown")
    }
}

struct DDRSuggestionsSection: View {
    @EnvironmentObject var navigationManager: NavigationManager

    @Bindable var model: DDRAnalyticsModel
    @Binding var isEditing: Bool
    var analyticsNamespace: Namespace.ID

    @AppStorage(wrappedValue: DDRPlayStyle.single, "Global.DDR.Style") var ddrStyleToShow: DDRPlayStyle
    @State var isShowingShareCard: Bool = false

    var rowLimit: Int {
        isEditing ? AnalyticsSuggestionCardID.editingPreviewLimit : AnalyticsSuggestionCardID.sectionLimit
    }

    var body: some View {
        AnalyticsSuggestionsSection(
            cards: AnalyticsSuggestionCardID.ddrCards,
            isEditing: isEditing,
            title: { _ in LocalizedStringKey("FLARE SKILL") },
            canShare: { _ in !model.flareSkillSuggestions.isEmpty },
            onShare: { _ in isShowingShareCard = true }
        ) { _ in
            AnalyticsSuggestionPreviewRows(items: model.flareSkillSuggestions, limit: rowLimit) { suggestion in
                navigationManager.push(DDRScoresPath.scoreViewer(songRecord: suggestion.record))
            } row: { suggestion in
                DDRFlareSkillSuggestionRow(suggestion: suggestion)
            }
        }
        .sheet(isPresented: $isShowingShareCard) {
            ShareCardComposer(
                game: .danceDanceRevolution,
                profile: .ddr(style: ddrStyleToShow),
                entries: model.flareSkillSuggestions.prefix(AnalyticsSuggestionCardID.sectionLimit).map {
                    ShareCardEntry(ddrSongRecord: $0.record)
                },
                playStyle: ddrStyleToShow == .single ? "SP" : "DP"
            )
        }
    }
}
