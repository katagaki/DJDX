import Charts
import OrderedCollections
import SwiftUI

struct DDRAnalyticsView: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @Bindable var model: DDRAnalyticsModel

    @AppStorage(wrappedValue: DDRVersion.world, "Global.DDR.Version") var ddrVersion: DDRVersion
    @AppStorage(wrappedValue: DDRPlayStyle.single, "Global.DDR.Style") var ddrStyleToShow: DDRPlayStyle

    @Binding var isEditing: Bool

    var analyticsNamespace: Namespace.ID

    @AppStorage(wrappedValue: Data(), "Analytics.DDR.CardOrder") var cardOrderData: Data
    @State var cardOrder: [DDRAnalyticsCard] = DDRAnalyticsCard.defaultOrder
    @State var draggedCard: DDRAnalyticsCard?

    @AppStorage(wrappedValue: Data(), "Analytics.DDR.VisibleCards") var visibleCardsData: Data
    @State var visibleCards: Set<DDRAnalyticsCard> = DDRAnalyticsCard.defaultVisible

    @AppStorage(wrappedValue: false, "Analytics.DDR.OverviewCollapsed") var isOverviewCollapsedStored: Bool
    @State var isOverviewCollapsed: Bool = false

    let cardColumns = [
        GridItem(.flexible(), spacing: 12.0),
        GridItem(.flexible(), spacing: 12.0)
    ]

    var body: some View {
        VStack(spacing: 20.0) {
            overviewSection
        }
        .padding(.top, 20.0)
        .onAppear {
            loadCardOrder()
            loadVisibleCards()
            isOverviewCollapsed = isOverviewCollapsedStored
        }
        .task {
            if model.dataState == .initializing {
                await model.reload(version: ddrVersion, style: ddrStyleToShow)
            }
        }
        .onChange(of: ddrVersion) { _, _ in
            Task { await model.reload(version: ddrVersion, style: ddrStyleToShow) }
        }
        .onChange(of: ddrStyleToShow) { _, _ in
            Task { await model.reload(version: ddrVersion, style: ddrStyleToShow) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await model.reload(version: ddrVersion, style: ddrStyleToShow) }
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
                                .ddrCardDraggable(cardType, editing: isEditing,
                                                  draggedCard: $draggedCard, cardOrder: $cardOrder,
                                                  onReorder: saveCardOrder)
                        }
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
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: cardType.transitionID, in: analyticsNamespace)
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

    func clearLabel(_ key: String) -> String {
        key == DDRSongRecord.noClearKey ? "NO CLEAR" : key.uppercased()
    }

    var clearBreakdownCard: some View {
        AnalyticsCardView(title: "Analytics.DDR.ClearBreakdown",
                          systemImage: "",
                          iconColor: .clear,
                          contentHeight: 160.0,
                          showsHeader: false) {
            Chart(totalClearCounts.elements.filter { $0.value > 0 }, id: \.key) { element in
                BarMark(
                    x: .value("Shared.ClearCount", element.value),
                    y: .value("Type", clearLabel(element.key))
                )
                .foregroundStyle(DDRSongRecord.clearColor(for: element.key))
            }
            .chartXAxis { AxisMarks { AxisGridLine() } }
        }
        .perLevelCaption("Analytics.DDR.ClearBreakdown")
    }

    var rankBreakdownCard: some View {
        AnalyticsCardView(title: "Analytics.DDR.RankBreakdown",
                          systemImage: "",
                          iconColor: .clear,
                          contentHeight: 160.0,
                          showsHeader: false) {
            Chart(totalRankCounts.elements.filter { $0.value > 0 }, id: \.key) { element in
                BarMark(
                    x: .value("Shared.ClearCount", element.value),
                    y: .value("Rank", DDRSongRecord.rankDisplay(forStem: element.key))
                )
                .foregroundStyle(DDRSongRecord.rankColor(forStem: element.key))
            }
            .chartXAxis { AxisMarks { AxisGridLine() } }
        }
        .perLevelCaption("Analytics.DDR.RankBreakdown")
    }
}
