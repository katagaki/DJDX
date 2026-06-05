import SwiftUI

struct PolarisChordAnalyticsView: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @Bindable var model: PolarisChordAnalyticsModel

    @AppStorage(wrappedValue: PolarisChordVersion.polarisChord, "Global.PolarisChord.Version")
    var polarisChordVersion: PolarisChordVersion

    @Binding var isEditing: Bool

    var analyticsNamespace: Namespace.ID

    @AppStorage(wrappedValue: Data(), "Analytics.PolarisChord.CardOrder") var cardOrderData: Data
    @State var cardOrder: [PolarisChordAnalyticsCard] = PolarisChordAnalyticsCard.defaultOrder
    @State var draggedCard: PolarisChordAnalyticsCard?

    @AppStorage(wrappedValue: Data(), "Analytics.PolarisChord.VisibleCards") var visibleCardsData: Data
    @State var visibleCards: Set<PolarisChordAnalyticsCard> = PolarisChordAnalyticsCard.defaultVisible

    // Persisted store; `isLastPlayCollapsed` mirrors it so a global `withAnimation`
    // can drive the collapse (animating @AppStorage directly does not work).
    @AppStorage(wrappedValue: false, "Analytics.PolarisChord.LastPlayCollapsed") var isLastPlayCollapsedStored: Bool
    @State var isLastPlayCollapsed: Bool = false

    var body: some View {
        VStack(spacing: 20.0) {
            lastPlaySection
        }
        .padding(.top, 20.0)
        .onAppear {
            loadCardOrder()
            loadVisibleCards()
            isLastPlayCollapsed = isLastPlayCollapsedStored
        }
        .task {
            if model.dataState == .initializing {
                await model.reload(version: polarisChordVersion)
            }
        }
        .onChange(of: polarisChordVersion) { _, _ in
            Task { await model.reload(version: polarisChordVersion) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await model.reload(version: polarisChordVersion) }
        }
    }

    // MARK: - Sections

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
    func lastPlayCardView(for cardType: PolarisChordAnalyticsCard) -> some View {
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
    func lastPlayCountCard(for cardType: PolarisChordAnalyticsCard) -> some View {
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
}
