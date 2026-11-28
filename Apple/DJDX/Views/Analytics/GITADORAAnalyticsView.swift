import Charts
import OrderedCollections
import SwiftUI

struct GITADORAAnalyticsView: View {

    @Environment(\.colorScheme) var colorScheme

    @EnvironmentObject var navigationManager: NavigationManager

    @Bindable var model: GITADORAAnalyticsModel

    @AppStorage(wrappedValue: GITADORAVersion.galaxyWaveDelta, "Global.GITADORA.Version")
    var gitadoraVersion: GITADORAVersion
    @AppStorage(wrappedValue: GITADORAInstrument.guitar, "Global.GITADORA.Instrument")
    var instrument: GITADORAInstrument
    @AppStorage(wrappedValue: [], "GITADORAScoresView.DifficultyFilters")
    var difficultiesToShow: Set<GITADORADifficulty>
    @AppStorage(wrappedValue: [], "GITADORAScoresView.LevelFilters")
    var levelsToShow: Set<String>
    @AppStorage(wrappedValue: [], "GITADORAScoresView.ClearTypeFilters")
    var clearTypesToShow: Set<GITADORAClearType>
    @AppStorage(wrappedValue: [], "GITADORAScoresView.RankFilters")
    var ranksToShow: Set<GITADORARank>

    @Binding var isEditing: Bool

    var analyticsNamespace: Namespace.ID

    @AppStorage(wrappedValue: Data(), "Analytics.GITADORA.CardOrder") var cardOrderData: Data
    @State var cardOrder: [GITADORAAnalyticsCard] = GITADORAAnalyticsCard.defaultOrder
    @State var draggedCard: GITADORAAnalyticsCard?

    @AppStorage(wrappedValue: Data(), "Analytics.GITADORA.VisibleCards") var visibleCardsData: Data
    @State var visibleCards: Set<GITADORAAnalyticsCard> = GITADORAAnalyticsCard.defaultVisible

    @AppStorage(wrappedValue: false, "Analytics.GITADORA.OverviewCollapsed") var isOverviewCollapsedStored: Bool
    @State var isOverviewCollapsed: Bool = false

    @AppStorage(wrappedValue: false, "Analytics.GITADORA.LastPlayCollapsed") var isLastPlayCollapsedStored: Bool
    @State var isLastPlayCollapsed: Bool = false
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.overviewKey) var isOverviewVisible: Bool
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.lastPlayKey) var isLastPlayVisible: Bool

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
        .onChange(of: gitadoraVersion) { _, _ in
            Task { await reload() }
        }
        .onChange(of: instrument) { _, _ in
            Task { await reload() }
        }
        .onChange(of: filters) { _, _ in
            Task { await reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await reload() }
        }
    }

    var filters: GITADORAFilterOptions {
        GITADORAFilterOptions(difficulties: difficultiesToShow,
                                  levels: levelsToShow,
                                  clearTypes: clearTypesToShow,
                                  ranks: ranksToShow)
    }

    func reload() async {
        await model.reload(version: gitadoraVersion, instrument: instrument, filters: filters)
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
                            .gitadoraCardDraggable(cardType, editing: isEditing,
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
                                    .gitadoraCardDraggable(cardType, editing: isEditing,
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
    func overviewCardView(for cardType: GITADORAAnalyticsCard) -> some View {
        Button {
            if !isEditing, let destination = cardType.destination {
                navigationManager.push(destination)
            }
        } label: {
            switch cardType {
            case .skill: skillCard
            case .clearBreakdown: clearBreakdownCard
            case .rankBreakdown: rankBreakdownCard
            default: EmptyView()
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .matchedTransitionSource(id: cardType.transitionID, in: analyticsNamespace)
    }

    @ViewBuilder
    func lastPlayCardView(for cardType: GITADORAAnalyticsCard) -> some View {
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
    func lastPlayCountCard(for cardType: GITADORAAnalyticsCard) -> some View {
        let count = lastPlayCount(for: cardType)
        CountTile(count: count, title: cardType.titleText, railColor: cardType.iconColor)
    }

    var cardCornerRadius: CGFloat {
        return 20.0
    }

    func lastPlayCount(for cardType: GITADORAAnalyticsCard) -> Int {
        if cardType == .newHighScores { return model.newHighScores.count }
        if let clearType = cardType.clearType { return model.newClears[clearType]?.count ?? 0 }
        if let rank = cardType.rank { return model.newRanks[rank]?.count ?? 0 }
        return 0
    }

    // MARK: - Card storage

    func loadCardOrder() {
        if let decoded = try? JSONDecoder().decode([GITADORAAnalyticsCard].self, from: cardOrderData),
           !decoded.isEmpty {
            var order = decoded
            for cardType in GITADORAAnalyticsCard.defaultOrder where !order.contains(cardType) {
                order.append(cardType)
            }
            order.removeAll { !GITADORAAnalyticsCard.defaultOrder.contains($0) }
            cardOrder = order
        }
    }

    func saveCardOrder() {
        cardOrderData = (try? JSONEncoder().encode(cardOrder)) ?? Data()
    }

    func loadVisibleCards() {
        if let decoded = try? JSONDecoder().decode(Set<GITADORAAnalyticsCard>.self, from: visibleCardsData) {
            visibleCards = decoded
        }
    }

    func saveVisibleCards() {
        visibleCardsData = (try? JSONEncoder().encode(visibleCards)) ?? Data()
    }

    func toggleCard(_ cardType: GITADORAAnalyticsCard) {
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
            uniqueKeys: GITADORAClearType.sortedStringsWithoutNoPlay,
            values: GITADORAClearType.sortedStringsWithoutNoPlay.map { _ in 0 }
        )
        for (_, counts) in model.clearTypePerDifficulty {
            for (key, value) in counts {
                totals[key, default: 0] += value
            }
        }
        return totals
    }

    var totalGradeCounts: OrderedDictionary<String, Int> {
        var totals: OrderedDictionary<String, Int> = OrderedDictionary(
            uniqueKeys: GITADORARank.sortedStrings,
            values: GITADORARank.sortedStrings.map { _ in 0 }
        )
        for (_, counts) in model.rankPerDifficulty {
            for (key, value) in counts {
                totals[key, default: 0] += value
            }
        }
        return totals
    }

    var skillCard: some View {
        AnalyticsCardView(title: "Shared.GITADORA.Skill",
                          contentHeight: 160.0,
                          showsHeader: false) {
            VStack(alignment: .leading, spacing: 4.0) {
                Text(verbatim: model.skill ?? "-")
                    .font(.system(size: 32.0, weight: .black))
                    .fontWidth(.condensed)
                    .italic()
                    .monospacedDigit()
                    .foregroundStyle(gitadoraVersion.color)
                Text(verbatim: instrument.displayName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0.0)
                ForEach(model.topSkillRecords.prefix(3), id: \.self) { record in
                    HStack(spacing: 4.0) {
                        Text(record.title)
                            .lineLimit(1)
                        Spacer(minLength: 0.0)
                        Text(verbatim: String(format: "%.2f", record.skillValue))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .perLevelCaption("Shared.GITADORA.Skill")
    }

    var clearBreakdownCard: some View {
        AnalyticsCardView(title: "Analytics.GITADORA.ClearBreakdown",
                          contentHeight: 160.0,
                          showsHeader: false) {
            StackedBreakdownBar(items: totalClearCounts.elements.filter { $0.value > 0 }.map { element in
                StackedBreakdownItem(label: clearLabel(element.key), value: element.value,
                                       color: GITADORAClearType(rawValue: element.key)?.color ?? .gray)
            })
        }
        .perLevelCaption("Analytics.GITADORA.ClearBreakdown")
    }

    var rankBreakdownCard: some View {
        AnalyticsCardView(title: "Analytics.GITADORA.RankBreakdown",
                          contentHeight: 160.0,
                          showsHeader: false) {
            StackedBreakdownBar(items: totalGradeCounts.elements.filter { $0.value > 0 }.map { element in
                StackedBreakdownItem(label: element.key, value: element.value,
                                       style: gradeStyle(element.key))
            })
        }
        .perLevelCaption("Analytics.GITADORA.RankBreakdown")
    }

    func clearLabel(_ rawValue: String) -> String {
        GITADORAClearType(rawValue: rawValue)?.abbreviation ?? rawValue
    }

    func gradeStyle(_ rawValue: String) -> AnyShapeStyle {
        let grade = GITADORARank(rawValue: rawValue) ?? .unknown
        return AnyShapeStyle(grade.style(colorScheme: colorScheme))
    }
}
