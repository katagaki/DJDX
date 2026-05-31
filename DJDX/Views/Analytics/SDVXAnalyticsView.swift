import Charts
import OrderedCollections
import SwiftUI
import UniformTypeIdentifiers

struct SDVXAnalyticsView: View {

    @Bindable var model: SDVXAnalyticsModel

    @AppStorage(wrappedValue: SDVXVersion.nabla, "Global.SDVX.Version") var sdvxVersion: SDVXVersion

    @Binding var isEditing: Bool

    @AppStorage(wrappedValue: Data(), "Analytics.SDVX.CardOrder") var cardOrderData: Data
    @State var cardOrder: [SDVXAnalyticsCard] = SDVXAnalyticsCard.defaultOrder
    @State var draggedCard: SDVXAnalyticsCard?

    @AppStorage(wrappedValue: Data(), "Analytics.SDVX.VisibleCards") var visibleCardsData: Data
    @State var visibleCards: Set<SDVXAnalyticsCard> = Set(SDVXAnalyticsCard.allCases)

    // Persisted store; `isOverviewCollapsed` mirrors it so a global `withAnimation`
    // can drive the collapse (animating @AppStorage directly does not work).
    @AppStorage(wrappedValue: false, "Analytics.SDVX.OverviewCollapsed") var isOverviewCollapsedStored: Bool
    @State var isOverviewCollapsed: Bool = false

    let cardColumns = [
        GridItem(.flexible(), spacing: 12.0),
        GridItem(.flexible(), spacing: 12.0)
    ]

    var body: some View {
        VStack(spacing: 20.0) {
            let shownCards = isEditing ? cardOrder : cardOrder.filter { visibleCards.contains($0) }
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
                                cardView(for: cardType)
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
        .padding(.top, 20.0)
        .onAppear {
            loadCardOrder()
            loadVisibleCards()
            isOverviewCollapsed = isOverviewCollapsedStored
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

    @ViewBuilder
    func cardView(for cardType: SDVXAnalyticsCard) -> some View {
        switch cardType {
        case .clearBreakdown: clearBreakdownCard
        case .gradeBreakdown: gradeBreakdownCard
        }
    }

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
                .foregroundStyle(LinearGradient(colors: [.yellow, .orange],
                                                startPoint: .leading, endPoint: .trailing))
            }
            .chartXAxis { AxisMarks { AxisGridLine() } }
        }
        .perLevelCaption("Analytics.SDVX.GradeBreakdown")
    }

    func clearLabel(_ rawValue: String) -> String {
        SDVXClearType(rawValue: rawValue)?.abbreviation ?? rawValue
    }
}

enum SDVXAnalyticsCard: String, Codable, Hashable, CaseIterable {
    case clearBreakdown
    case gradeBreakdown

    static var defaultOrder: [SDVXAnalyticsCard] { allCases }
}

extension View {
    @ViewBuilder
    func sdvxCardDraggable(
        _ cardType: SDVXAnalyticsCard,
        editing: Bool,
        draggedCard: Binding<SDVXAnalyticsCard?>,
        cardOrder: Binding<[SDVXAnalyticsCard]>,
        onReorder: @escaping () -> Void
    ) -> some View {
        if editing {
            self
                .opacity(draggedCard.wrappedValue == cardType ? 0.4 : 1.0)
                .onDrag {
                    draggedCard.wrappedValue = cardType
                    return NSItemProvider(object: cardType.rawValue as NSString)
                }
                .onDrop(of: [.text], delegate: SDVXCardReorderDropDelegate(
                    target: cardType,
                    cards: cardOrder,
                    draggedCard: draggedCard,
                    onReorder: onReorder
                ))
        } else {
            self
        }
    }
}

struct SDVXCardReorderDropDelegate: DropDelegate {
    let target: SDVXAnalyticsCard
    @Binding var cards: [SDVXAnalyticsCard]
    @Binding var draggedCard: SDVXAnalyticsCard?
    let onReorder: () -> Void

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info _: DropInfo) -> Bool {
        draggedCard = nil
        return true
    }

    func dropEntered(info _: DropInfo) {
        guard let draggedCard, draggedCard != target else { return }
        guard let fromIndex = cards.firstIndex(of: draggedCard),
              let toIndex = cards.firstIndex(of: target) else { return }

        withAnimation(.snappy(duration: 0.3)) {
            cards.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
        onReorder()
    }

    func dropExited(info _: DropInfo) {
        // No cleanup needed when a drag leaves this target
    }
}
