import Charts
import OrderedCollections
import SwiftUI

struct PolarisChordAnalyticsView: View {

    @Environment(\.colorScheme) var colorScheme

    @EnvironmentObject var navigationManager: NavigationManager

    @Bindable var model: PolarisChordAnalyticsModel

    @AppStorage(wrappedValue: PolarisChordVersion.polarisChord, "Global.PolarisChord.Version")
    var polarisChordVersion: PolarisChordVersion
    @AppStorage(wrappedValue: [], "PolarisChordScoresView.DifficultyFilters")
    var difficultiesToShow: Set<PolarisChordDifficulty>
    @AppStorage(wrappedValue: [], "PolarisChordScoresView.LevelFilters")
    var levelsToShow: Set<String>
    @AppStorage(wrappedValue: [], "PolarisChordScoresView.ClearTypeFilters")
    var clearTypesToShow: Set<PolarisChordClearType>
    @AppStorage(wrappedValue: [], "PolarisChordScoresView.GradeFilters")
    var gradesToShow: Set<PolarisChordGrade>

    @Binding var isEditing: Bool

    var analyticsNamespace: Namespace.ID

    @AppStorage(wrappedValue: Data(), "Analytics.PolarisChord.CardOrder") var cardOrderData: Data
    @State var cardOrder: [PolarisChordAnalyticsCard] = PolarisChordAnalyticsCard.defaultOrder
    @State var draggedCard: PolarisChordAnalyticsCard?

    @AppStorage(wrappedValue: Data(), "Analytics.PolarisChord.VisibleCards") var visibleCardsData: Data
    @State var visibleCards: Set<PolarisChordAnalyticsCard> = PolarisChordAnalyticsCard.defaultVisible

    @AppStorage(wrappedValue: false, "Analytics.PolarisChord.OverviewCollapsed") var isOverviewCollapsedStored: Bool
    @State var isOverviewCollapsed: Bool = false

    @AppStorage(wrappedValue: false, "Analytics.PolarisChord.LastPlayCollapsed") var isLastPlayCollapsedStored: Bool
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
        .onChange(of: isEditing) { _, isEditing in
            if !isEditing {
                saveCardOrder()
            }
        }
        .task {
            if model.dataState == .initializing {
                await reload()
            }
        }
        .onChange(of: polarisChordVersion) { _, _ in
            Task { await reload() }
        }
        .onChange(of: filters) { _, _ in
            Task { await reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await reload() }
        }
    }

    var filters: PolarisChordFilterOptions {
        PolarisChordFilterOptions(difficulties: difficultiesToShow,
                                  levels: levelsToShow,
                                  clearTypes: clearTypesToShow,
                                  grades: gradesToShow)
    }

    func reload() async {
        await model.reload(version: polarisChordVersion, filters: filters)
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
                            .polarisChordCardDraggable(cardType, editing: isEditing,
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
                                    .polarisChordCardDraggable(cardType, editing: isEditing,
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
    func overviewCardView(for cardType: PolarisChordAnalyticsCard) -> some View {
        Button {
            if !isEditing, let destination = cardType.destination {
                navigationManager.push(destination)
            }
        } label: {
            switch cardType {
            case .clearBreakdown: clearBreakdownCard
            case .gradeBreakdown: gradeBreakdownCard
            default: EmptyView()
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .matchedTransitionSource(id: cardType.transitionID, in: analyticsNamespace)
    }

    @ViewBuilder
    func lastPlayCardView(for cardType: PolarisChordAnalyticsCard) -> some View {
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
    func lastPlayCountCard(for cardType: PolarisChordAnalyticsCard) -> some View {
        let count = lastPlayCount(for: cardType)
        CountTile(count: count, title: cardType.titleText, railColor: cardType.iconColor)
    }

    var cardCornerRadius: CGFloat {
        return 20.0
    }

    func lastPlayCount(for cardType: PolarisChordAnalyticsCard) -> Int {
        if cardType == .newHighScores { return model.newHighScores.count }
        if let clearType = cardType.clearType { return model.newClears[clearType]?.count ?? 0 }
        if let grade = cardType.grade { return model.newGrades[grade]?.count ?? 0 }
        return 0
    }

    // MARK: - Card storage

    func loadCardOrder() {
        if let decoded = try? JSONDecoder().decode([PolarisChordAnalyticsCard].self, from: cardOrderData),
           !decoded.isEmpty {
            var order = decoded
            for cardType in PolarisChordAnalyticsCard.defaultOrder where !order.contains(cardType) {
                order.append(cardType)
            }
            order.removeAll { !PolarisChordAnalyticsCard.defaultOrder.contains($0) }
            cardOrder = order
        }
    }

    func saveCardOrder() {
        cardOrderData = (try? JSONEncoder().encode(cardOrder)) ?? Data()
    }

    func loadVisibleCards() {
        if let decoded = try? JSONDecoder().decode(Set<PolarisChordAnalyticsCard>.self, from: visibleCardsData) {
            visibleCards = decoded
        }
    }

    func saveVisibleCards() {
        visibleCardsData = (try? JSONEncoder().encode(visibleCards)) ?? Data()
    }

    func toggleCard(_ cardType: PolarisChordAnalyticsCard) {
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

    // Aggregate clear-type counts across all difficulty categories
    var totalClearCounts: OrderedDictionary<String, Int> {
        var totals: OrderedDictionary<String, Int> = OrderedDictionary(
            uniqueKeys: PolarisChordClearType.sortedStringsWithoutNoPlay,
            values: PolarisChordClearType.sortedStringsWithoutNoPlay.map { _ in 0 }
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
            uniqueKeys: PolarisChordGrade.sortedStrings,
            values: PolarisChordGrade.sortedStrings.map { _ in 0 }
        )
        for (_, counts) in model.gradePerDifficulty {
            for (key, value) in counts {
                totals[key, default: 0] += value
            }
        }
        return totals
    }

    var clearBreakdownCard: some View {
        AnalyticsCardView(title: "Analytics.PolarisChord.ClearBreakdown",
                          contentHeight: 160.0,
                          showsHeader: false) {
            StackedBreakdownBar(items: totalClearCounts.elements.filter { $0.value > 0 }.map { element in
                StackedBreakdownItem(label: clearLabel(element.key), value: element.value,
                                       color: PolarisChordClearType(rawValue: element.key)?.color ?? .gray)
            })
        }
        .perLevelCaption("Analytics.PolarisChord.ClearBreakdown")
    }

    var gradeBreakdownCard: some View {
        AnalyticsCardView(title: "Analytics.PolarisChord.GradeBreakdown",
                          contentHeight: 160.0,
                          showsHeader: false) {
            StackedBreakdownBar(items: totalGradeCounts.elements.filter { $0.value > 0 }.map { element in
                StackedBreakdownItem(label: element.key, value: element.value,
                                       style: gradeStyle(element.key))
            })
        }
        .perLevelCaption("Analytics.PolarisChord.GradeBreakdown")
    }

    func clearLabel(_ rawValue: String) -> String {
        PolarisChordClearType(rawValue: rawValue)?.abbreviation ?? rawValue
    }

    func gradeStyle(_ rawValue: String) -> AnyShapeStyle {
        let grade = PolarisChordGrade(rawValue: rawValue) ?? .unknown
        return AnyShapeStyle(grade.style(colorScheme: colorScheme))
    }
}
