import Charts
import OrderedCollections
import SwiftUI

struct PopnAnalyticsView: View {

    @Environment(\.colorScheme) var colorScheme

    @EnvironmentObject var navigationManager: NavigationManager

    @Bindable var model: PopnAnalyticsModel

    @AppStorage(wrappedValue: PopnVersion.highCheers, "Global.Popn.Version") var popnVersion: PopnVersion
    @AppStorage(wrappedValue: [], "PopnScoresView.DifficultyFilters")
    var difficultiesToShow: Set<PopnDifficulty>
    @AppStorage(wrappedValue: [], "PopnScoresView.LevelFilters")
    var levelsToShow: Set<String>
    @AppStorage(wrappedValue: [], "PopnScoresView.ClearTypeFilters")
    var clearTypesToShow: Set<PopnClearType>
    @AppStorage(wrappedValue: [], "PopnScoresView.RankFilters")
    var ranksToShow: Set<PopnRank>

    @Binding var isEditing: Bool

    var analyticsNamespace: Namespace.ID

    @AppStorage(wrappedValue: Data(), "Analytics.Popn.CardOrder") var cardOrderData: Data
    @State var cardOrder: [PopnAnalyticsCard] = PopnAnalyticsCard.defaultOrder
    @State var draggedCard: PopnAnalyticsCard?

    @AppStorage(wrappedValue: Data(), "Analytics.Popn.VisibleCards") var visibleCardsData: Data
    @State var visibleCards: Set<PopnAnalyticsCard> = PopnAnalyticsCard.defaultVisible

    @AppStorage(wrappedValue: false, "Analytics.Popn.OverviewCollapsed") var isOverviewCollapsedStored: Bool
    @State var isOverviewCollapsed: Bool = false

    @AppStorage(wrappedValue: false, "Analytics.Popn.LastPlayCollapsed") var isLastPlayCollapsedStored: Bool
    @State var isLastPlayCollapsed: Bool = false
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.overviewKey) var isOverviewVisible: Bool
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.lastPlayKey) var isLastPlayVisible: Bool

    let cardColumns = [
        GridItem(.flexible(), spacing: DesignMetrics.gap),
        GridItem(.flexible(), spacing: DesignMetrics.gap)
    ]

    var body: some View {
        VStack(spacing: DesignMetrics.sectionGap) {
            if isOverviewVisible {
                overviewSection
            }
            if isLastPlayVisible {
                lastPlaySection
            }
        }
        .padding(.top, (isOverviewVisible || isLastPlayVisible) ? DesignMetrics.topPadding : 0.0)
        .onAppear {
            loadCardOrder()
            loadVisibleCards()
            isOverviewCollapsed = isOverviewCollapsedStored
            isLastPlayCollapsed = isLastPlayCollapsedStored
        }
        .task {
            if model.dataState == .initializing {
                await reload()
            }
        }
        .onChange(of: popnVersion) { _, _ in
            Task { await reload() }
        }
        .onChange(of: filters) { _, _ in
            Task { await reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await reload() }
        }
    }

    var filters: PopnFilterOptions {
        PopnFilterOptions(difficulties: difficultiesToShow,
                          levels: levelsToShow,
                          clearTypes: clearTypesToShow,
                          ranks: ranksToShow)
    }

    func reload() async {
        await model.reload(version: popnVersion, filters: filters)
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
                            .popnCardDraggable(cardType, editing: isEditing,
                                               draggedCard: $draggedCard, cardOrder: $cardOrder,
                                               onReorder: saveCardOrder)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    @ViewBuilder
    var lastPlaySection: some View {
        let lastPlayCards = cardOrder.filter { $0.section == .lastPlay }
        let shownCards = isEditing ? lastPlayCards : lastPlayCards.filter {
            visibleCards.contains($0) && lastPlayCount(for: $0) > 0
        }
        if !shownCards.isEmpty {
            let isExpanded = isEditing || !isLastPlayCollapsed
            VStack(spacing: DesignMetrics.gap) {
                AnalyticsSectionHeader(
                    title: AnalyticsSection.lastPlay.titleKey,
                    isCollapsible: !isEditing,
                    isExpanded: isExpanded
                ) {
                    withAnimation(.smooth.speed(2.0)) { isLastPlayCollapsed.toggle() }
                    isLastPlayCollapsedStored = isLastPlayCollapsed
                }
                if isExpanded {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignMetrics.gap) {
                            ForEach(shownCards, id: \.self) { cardType in
                                lastPlayCardView(for: cardType)
                                    .editableCard(isVisible: visibleCards.contains(cardType),
                                                  isEditing: isEditing,
                                                  seed: cardOrder.firstIndex(of: cardType) ?? 0) {
                                        toggleCard(cardType)
                                    }
                                    .popnCardDraggable(cardType, editing: isEditing,
                                                       draggedCard: $draggedCard, cardOrder: $cardOrder,
                                                       onReorder: saveCardOrder)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: - Cards

    @ViewBuilder
    func overviewCardView(for cardType: PopnAnalyticsCard) -> some View {
        Button {
            if !isEditing, let destination = cardType.destination {
                navigationManager.push(destination)
            }
        } label: {
            switch cardType {
            case .popnClass: popnClassCard
            case .medalBreakdown: medalBreakdownCard
            case .rankBreakdown: rankBreakdownCard
            default: EmptyView()
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .matchedTransitionSource(id: cardType.transitionID, in: analyticsNamespace)
    }

    @ViewBuilder
    func lastPlayCardView(for cardType: PopnAnalyticsCard) -> some View {
        Button {
            if !isEditing, let destination = cardType.destination {
                navigationManager.push(destination)
            }
        } label: {
            lastPlayCountCard(for: cardType)
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .matchedTransitionSource(id: cardType.transitionID, in: analyticsNamespace)
    }

    @ViewBuilder
    func lastPlayCountCard(for cardType: PopnAnalyticsCard) -> some View {
        let count = lastPlayCount(for: cardType)
        CountTile(count: count, title: cardType.titleText, railColor: cardType.iconColor)
    }


    func lastPlayCount(for cardType: PopnAnalyticsCard) -> Int {
        if cardType == .newHighScores { return model.newHighScores.count }
        if let clearType = cardType.clearType { return model.newClears[clearType]?.count ?? 0 }
        if let rank = cardType.rank { return model.newRanks[rank]?.count ?? 0 }
        return 0
    }

    // MARK: - Card storage

    func loadCardOrder() {
        if let decoded = try? JSONDecoder().decode([PopnAnalyticsCard].self, from: cardOrderData),
           !decoded.isEmpty {
            var order = decoded
            for cardType in PopnAnalyticsCard.defaultOrder where !order.contains(cardType) {
                order.append(cardType)
            }
            order.removeAll { !PopnAnalyticsCard.defaultOrder.contains($0) }
            cardOrder = order
        }
    }

    func saveCardOrder() {
        cardOrderData = (try? JSONEncoder().encode(cardOrder)) ?? Data()
    }

    func loadVisibleCards() {
        if let decoded = try? JSONDecoder().decode(Set<PopnAnalyticsCard>.self, from: visibleCardsData) {
            visibleCards = decoded
        }
    }

    func saveVisibleCards() {
        visibleCardsData = (try? JSONEncoder().encode(visibleCards)) ?? Data()
    }

    func toggleCard(_ cardType: PopnAnalyticsCard) {
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

    var popnClassCard: some View {
        AnalyticsCardView(title: "Shared.Popn.PopnClass",
                          contentHeight: 160.0,
                          showsHeader: false) {
            let tier = model.popnClassTier
            VStack(alignment: .leading, spacing: 4.0) {
                Spacer(minLength: 0.0)
                Text(verbatim: tier.name)
                    .font(.headline.bold())
                    .foregroundStyle(tier.color)
                Text(verbatim: model.popnClassText)
                    .font(.system(size: 34.0, weight: .black))
                    .fontWidth(.expanded)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .perLevelCaption("Shared.Popn.PopnClass")
    }

    var medalBreakdownCard: some View {
        AnalyticsCardView(title: "Analytics.Popn.MedalBreakdown",
                          contentHeight: 160.0,
                          showsHeader: false) {
            StackedBreakdownBar(items: model.clearTypeTotals.elements.filter { $0.value > 0 }.map { element in
                StackedBreakdownItem(label: PopnClearType(rawValue: element.key)?.abbreviation ?? element.key,
                                     value: element.value,
                                     color: PopnClearType(rawValue: element.key)?.color ?? .gray)
            })
        }
        .perLevelCaption("Analytics.Popn.MedalBreakdown")
    }

    var rankBreakdownCard: some View {
        AnalyticsCardView(title: "Analytics.Popn.RankBreakdown",
                          contentHeight: 160.0,
                          showsHeader: false) {
            StackedBreakdownBar(items: model.rankTotals.elements.filter { $0.value > 0 }.map { element in
                StackedBreakdownItem(label: element.key, value: element.value, style: rankStyle(element.key))
            })
        }
        .perLevelCaption("Analytics.Popn.RankBreakdown")
    }

    func rankStyle(_ rawValue: String) -> AnyShapeStyle {
        let rank = PopnRank(rawValue: rawValue) ?? .none
        return AnyShapeStyle(rank.style(colorScheme: colorScheme))
    }
}
