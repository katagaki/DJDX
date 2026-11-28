import Charts
import OrderedCollections
import SwiftUI
import UniformTypeIdentifiers

struct SDVXAnalyticsView: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @Bindable var model: SDVXAnalyticsModel

    @AppStorage(wrappedValue: SDVXVersion.nabla, "Global.SDVX.Version") var sdvxVersion: SDVXVersion
    @AppStorage(wrappedValue: [], "SDVXScoresView.DifficultyFilters") var difficultiesToShow: Set<SDVXDifficulty>
    @AppStorage(wrappedValue: [], "SDVXScoresView.LevelFilters") var levelBucketsToShow: Set<Double>
    @AppStorage(wrappedValue: [], "SDVXScoresView.ClearTypeFilters") var clearTypesToShow: Set<SDVXClearType>
    @AppStorage(wrappedValue: [], "SDVXScoresView.GradeFilters") var gradesToShow: Set<SDVXGrade>

    @Binding var isEditing: Bool

    var analyticsNamespace: Namespace.ID

    @AppStorage(wrappedValue: Data(), "Analytics.SDVX.CardOrder") var cardOrderData: Data
    @State var cardOrder: [SDVXAnalyticsCard] = SDVXAnalyticsCard.defaultOrder
    @State var draggedCard: SDVXAnalyticsCard?

    @AppStorage(wrappedValue: Data(), "Analytics.SDVX.VisibleCards") var visibleCardsData: Data
    @State var visibleCards: Set<SDVXAnalyticsCard> = SDVXAnalyticsCard.defaultVisible

    @AppStorage(wrappedValue: false, "Analytics.SDVX.OverviewCollapsed") var isOverviewCollapsedStored: Bool
    @State var isOverviewCollapsed: Bool = false

    @AppStorage(wrappedValue: false, "Analytics.SDVX.LastPlayCollapsed") var isLastPlayCollapsedStored: Bool
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
        .onChange(of: sdvxVersion) { _, _ in
            Task { await reload() }
        }
        .onChange(of: filters) { _, _ in
            Task { await reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await reload() }
        }
    }

    var filters: SDVXFilterOptions {
        SDVXFilterOptions(difficulties: difficultiesToShow,
                          levelBuckets: levelBucketsToShow,
                          clearTypes: clearTypesToShow,
                          grades: gradesToShow)
    }

    func reload() async {
        await model.reload(version: sdvxVersion, filters: filters)
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
                            .sdvxCardDraggable(cardType, editing: isEditing,
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
                                    .sdvxCardDraggable(cardType, editing: isEditing,
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
    func overviewCardView(for cardType: SDVXAnalyticsCard) -> some View {
        Button {
            if !isEditing, let destination = cardType.destination {
                navigationManager.push(destination)
            }
        } label: {
            switch cardType {
            case .clearBreakdown: clearBreakdownCard
            case .gradeBreakdown: gradeBreakdownCard
            case .volforceTrend: volforceTrendCard
            default: EmptyView()
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .matchedTransitionSource(id: cardType.transitionID, in: analyticsNamespace)
    }

    @ViewBuilder
    func lastPlayCardView(for cardType: SDVXAnalyticsCard) -> some View {
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
    func lastPlayCountCard(for cardType: SDVXAnalyticsCard) -> some View {
        let count = lastPlayCount(for: cardType)
        CountTile(count: count, title: cardType.titleText, railColor: cardType.iconColor)
    }

    var cardCornerRadius: CGFloat {
        return 20.0
    }

    func lastPlayCount(for cardType: SDVXAnalyticsCard) -> Int {
        if cardType == .newHighScores { return model.newHighScores.count }
        if let clearType = cardType.clearType { return model.newClears[clearType]?.count ?? 0 }
        if let grade = cardType.grade { return model.newGrades[grade]?.count ?? 0 }
        return 0
    }

    // MARK: - Card storage

    func loadCardOrder() {
        if let decoded = try? JSONDecoder().decode([SDVXAnalyticsCard].self, from: cardOrderData),
           !decoded.isEmpty {
            var order = decoded
            for cardType in SDVXAnalyticsCard.defaultOrder where !order.contains(cardType) {
                order.append(cardType)
            }
            order.removeAll { !SDVXAnalyticsCard.defaultOrder.contains($0) }
            cardOrder = order
        }
    }

    func saveCardOrder() {
        cardOrderData = (try? JSONEncoder().encode(cardOrder)) ?? Data()
    }

    func loadVisibleCards() {
        if let decoded = try? JSONDecoder().decode(Set<SDVXAnalyticsCard>.self, from: visibleCardsData) {
            visibleCards = decoded
        }
    }

    func saveVisibleCards() {
        visibleCardsData = (try? JSONEncoder().encode(visibleCards)) ?? Data()
    }

    func toggleCard(_ cardType: SDVXAnalyticsCard) {
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
            uniqueKeys: SDVXClearType.sortedStringsWithoutNoPlay,
            values: SDVXClearType.sortedStringsWithoutNoPlay.map { _ in 0 }
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
            uniqueKeys: SDVXGrade.sortedStrings,
            values: SDVXGrade.sortedStrings.map { _ in 0 }
        )
        for (_, counts) in model.gradePerDifficulty {
            for (key, value) in counts {
                totals[key, default: 0] += value
            }
        }
        return totals
    }

    var clearBreakdownCard: some View {
        AnalyticsCardView(title: "Analytics.SDVX.ClearBreakdown",
                          contentHeight: 160.0,
                          showsHeader: false) {
            StackedBreakdownBar(items: totalClearCounts.elements.filter { $0.value > 0 }.map { element in
                StackedBreakdownItem(label: clearLabel(element.key), value: element.value,
                                       color: SDVXClearType(rawValue: element.key)?.color ?? .gray)
            })
        }
        .perLevelCaption("Analytics.SDVX.ClearBreakdown")
    }

    var gradeBreakdownCard: some View {
        AnalyticsCardView(title: "Analytics.SDVX.GradeBreakdown",
                          contentHeight: 160.0,
                          showsHeader: false) {
            StackedBreakdownBar(items: totalGradeCounts.elements.filter { $0.value > 0 }.map { element in
                StackedBreakdownItem(label: element.key, value: element.value,
                                       color: SDVXGrade.color(for: element.key))
            })
        }
        .perLevelCaption("Analytics.SDVX.GradeBreakdown")
    }

    var volforceTrendCard: some View {
        AnalyticsCardView(title: "Analytics.SDVX.VolforceTrend",
                          contentHeight: 160.0,
                          showsHeader: false) {
            TrendCardContent(points: model.volforceHistory, color: .purple,
                             format: SDVXAnalyticsModel.formatVolforce)
        }
        .perLevelCaption("Analytics.SDVX.VolforceTrend")
    }

    func clearLabel(_ rawValue: String) -> String {
        SDVXClearType(rawValue: rawValue)?.abbreviation ?? rawValue
    }
}

struct SDVXSuggestionsSection: View {
    @EnvironmentObject var navigationManager: NavigationManager

    @Bindable var model: SDVXAnalyticsModel
    var analyticsNamespace: Namespace.ID

    @State var isShowingShareCard: Bool = false

    var body: some View {
        AnalyticsSuggestionsSection(
            cards: AnalyticsSuggestionCardID.sdvxCards,
            title: { _ in LocalizedStringKey("VOLFORCE") },
            canShare: { _ in !model.volforceSuggestions.isEmpty },
            onShare: { _ in isShowingShareCard = true }
        ) { _ in
            AnalyticsSuggestionPreviewRows(items: model.volforceSuggestions) { suggestion in
                navigationManager.push(SDVXScoresPath.scoreViewer(songRecord: suggestion.record))
            } row: { suggestion in
                SDVXVolforceSuggestionRow(namespace: analyticsNamespace, suggestion: suggestion)
            }
        }
        .sheet(isPresented: $isShowingShareCard) {
            ShareCardComposer(
                game: .soundVoltex,
                profile: .sdvx(),
                entries: model.volforceSuggestions.prefix(AnalyticsSuggestionCardID.sectionLimit).map {
                    ShareCardEntry(sdvxSongRecord: $0.record)
                }
            )
        }
    }
}
