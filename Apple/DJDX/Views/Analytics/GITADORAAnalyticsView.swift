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

    let cardColumns = [
        GridItem(.flexible(), spacing: 12.0),
        GridItem(.flexible(), spacing: 12.0)
    ]

    var body: some View {
        VStack(spacing: 20.0) {
            overviewSection
            lastPlaySection
        }
        .padding(.top, 20.0)
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
            VStack(spacing: 12.0) {
                AnalyticsSectionHeader(
                    title: AnalyticsSection.overview.titleKey,
                    isCollapsible: !isEditing,
                    isExpanded: isExpanded
                ) {
                    withAnimation(.smooth.speed(2.0)) { isOverviewCollapsed.toggle() }
                    isOverviewCollapsedStored = isOverviewCollapsed
                }
                if isExpanded {
                    LazyVGrid(columns: cardColumns, spacing: 12.0) {
                        ForEach(shownCards, id: \.self) { cardType in
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
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    @ViewBuilder
    var lastPlaySection: some View {
        let lastPlayCards = cardOrder.filter { $0.section == .lastPlay }
        let shownCards = isEditing ? lastPlayCards : lastPlayCards.filter { visibleCards.contains($0) }
        if !shownCards.isEmpty {
            let isExpanded = isEditing || !isLastPlayCollapsed
            VStack(spacing: 12.0) {
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
                        HStack(spacing: 12.0) {
                            ForEach(shownCards, id: \.self) { cardType in
                                lastPlayCardView(for: cardType)
                                    .frame(width: cardType == .newHighScores ? 130.0 : 96.0)
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
        VStack(alignment: .leading, spacing: 2.0) {
            Text("\(count)")
                .font(.system(size: 20.0, weight: .black))
                .fontWidth(.expanded)
                .foregroundStyle(count > 0 ? .primary : .secondary)
                .frame(height: 36.0, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 5.0) {
                Image(systemName: cardType.systemImage)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(cardType.iconColor)
                    .frame(width: 12.0, height: 12.0)
                cardType.titleText
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(cornerRadius: cardCornerRadius)
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
                          systemImage: "",
                          iconColor: .clear,
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
                          systemImage: "",
                          iconColor: .clear,
                          contentHeight: 160.0,
                          showsHeader: false) {
            Chart(totalClearCounts.elements.filter { $0.value > 0 }, id: \.key) { element in
                BarMark(
                    x: .value("Shared.ClearCount", element.value),
                    y: .value("Type", clearLabel(element.key))
                )
                .foregroundStyle(GITADORAClearType(rawValue: element.key)?.color ?? .gray)
            }
            .chartXAxis { AxisMarks { AxisGridLine() } }
        }
        .perLevelCaption("Analytics.GITADORA.ClearBreakdown")
    }

    var rankBreakdownCard: some View {
        AnalyticsCardView(title: "Analytics.GITADORA.RankBreakdown",
                          systemImage: "",
                          iconColor: .clear,
                          contentHeight: 160.0,
                          showsHeader: false) {
            Chart(totalGradeCounts.elements.filter { $0.value > 0 }, id: \.key) { element in
                BarMark(
                    x: .value("Shared.ClearCount", element.value),
                    y: .value("Grade", element.key)
                )
                .foregroundStyle(gradeStyle(element.key))
            }
            .chartXAxis { AxisMarks { AxisGridLine() } }
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
