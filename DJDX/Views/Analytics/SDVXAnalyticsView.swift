import Charts
import OrderedCollections
import SwiftUI
import UniformTypeIdentifiers

// swiftlint:disable type_body_length
struct SDVXAnalyticsView: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @Bindable var model: SDVXAnalyticsModel

    @AppStorage(wrappedValue: SDVXVersion.nabla, "Global.SDVX.Version") var sdvxVersion: SDVXVersion

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
                await model.reload(version: sdvxVersion)
            }
        }
        .onChange(of: sdvxVersion) { _, _ in
            Task { await model.reload(version: sdvxVersion) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await model.reload(version: sdvxVersion) }
        }
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
            default: EmptyView()
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: cardType.transitionID, in: analyticsNamespace)
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
        .automaticMatchedTransitionSource(id: cardType.transitionID, in: analyticsNamespace)
    }

    @ViewBuilder
    func lastPlayCountCard(for cardType: SDVXAnalyticsCard) -> some View {
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
        if #available(iOS 26.0, *) {
            return 20.0
        } else {
            return 12.0
        }
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
                          systemImage: "",
                          iconColor: .clear,
                          contentHeight: 160.0,
                          showsHeader: false) {
            Chart(totalClearCounts.elements.filter { $0.value > 0 }, id: \.key) { element in
                BarMark(
                    x: .value("Shared.ClearCount", element.value),
                    y: .value("Type", clearLabel(element.key))
                )
                .foregroundStyle(SDVXClearType(rawValue: element.key)?.color ?? .gray)
            }
            .chartXAxis { AxisMarks { AxisGridLine() } }
        }
        .perLevelCaption("Analytics.SDVX.ClearBreakdown")
    }

    var gradeBreakdownCard: some View {
        AnalyticsCardView(title: "Analytics.SDVX.GradeBreakdown",
                          systemImage: "",
                          iconColor: .clear,
                          contentHeight: 160.0,
                          showsHeader: false) {
            Chart(totalGradeCounts.elements.filter { $0.value > 0 }, id: \.key) { element in
                BarMark(
                    x: .value("Shared.ClearCount", element.value),
                    y: .value("Grade", element.key)
                )
                .foregroundStyle(SDVXGrade.color(for: element.key))
            }
            .chartXAxis { AxisMarks { AxisGridLine() } }
        }
        .perLevelCaption("Analytics.SDVX.GradeBreakdown")
    }

    func clearLabel(_ rawValue: String) -> String {
        SDVXClearType(rawValue: rawValue)?.abbreviation ?? rawValue
    }
}
// swiftlint:enable type_body_length
