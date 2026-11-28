import SwiftUI
import UniformTypeIdentifiers

// MARK: - Card Ordering & Persistence

extension AnalyticsView {

    func loadCardOrder() {
        if let decoded = try? JSONDecoder().decode([AnalyticsCardType].self, from: cardOrderData),
           !decoded.isEmpty {
            var order = decoded
            var addedCards: [AnalyticsCardType] = []
            for (index, cardType) in AnalyticsCardType.defaultOrder.enumerated() where !order.contains(cardType) {
                if index > 0,
                   let predecessorIndex = order.firstIndex(of: AnalyticsCardType.defaultOrder[index - 1]) {
                    order.insert(cardType, at: predecessorIndex + 1)
                } else {
                    order.append(cardType)
                }
                addedCards.append(cardType)
            }
            order.removeAll { !AnalyticsCardType.defaultOrder.contains($0) }
            cardOrder = order
            let addedVisibleCards = addedCards.filter { AnalyticsCardType.defaultVisible.contains($0) }
            if !addedVisibleCards.isEmpty {
                visibleCards.formUnion(addedVisibleCards)
                saveCardOrder()
                saveVisibleCards()
            }
        }
    }

    func saveCardOrder() {
        cardOrderData = (try? JSONEncoder().encode(cardOrder)) ?? Data()
    }

    func loadVisibleCards() {
        if let decoded = try? JSONDecoder().decode(Set<AnalyticsCardType>.self, from: visibleCardsData) {
            visibleCards = decoded
        }
    }

    func saveVisibleCards() {
        visibleCardsData = (try? JSONEncoder().encode(visibleCards)) ?? Data()
    }

    func loadPerLevelCardOrder() {
        if let decoded = try? JSONDecoder().decode([PerLevelCardID].self, from: perLevelCardOrderData),
           !decoded.isEmpty {
            var order = decoded
            for card in PerLevelCardID.defaultOrder where !order.contains(card) {
                order.append(card)
            }
            let validCards = Set(PerLevelCardID.defaultOrder)
            order.removeAll { !validCards.contains($0) }
            perLevelCardOrder = order
        }
    }

    func savePerLevelCardOrder() {
        perLevelCardOrderData = (try? JSONEncoder().encode(perLevelCardOrder)) ?? Data()
    }

    func loadVisiblePerLevelCards() {
        if let decoded = try? JSONDecoder().decode(
            Set<PerLevelCardID>.self, from: visiblePerLevelCardsData
        ) {
            visiblePerLevelCardSet = decoded
        }
    }

    func saveVisiblePerLevelCards() {
        visiblePerLevelCardsData = (try? JSONEncoder().encode(visiblePerLevelCardSet)) ?? Data()
    }

    func loadCollapsedSections() {
        if let decoded = try? JSONDecoder().decode(Set<AnalyticsSection>.self, from: collapsedSectionsData) {
            collapsedSections = decoded
        }
    }

    func saveCollapsedSections() {
        collapsedSectionsData = (try? JSONEncoder().encode(collapsedSections)) ?? Data()
    }

    func isSectionExpanded(_ section: AnalyticsSection) -> Bool {
        // While editing, always reveal a section's cards so they can be reordered.
        isEditing || !collapsedSections.contains(section)
    }

    func toggleSection(_ section: AnalyticsSection) {
        withAnimation(.smooth.speed(2.0)) {
            if collapsedSections.contains(section) {
                collapsedSections.remove(section)
            } else {
                collapsedSections.insert(section)
            }
        }
        saveCollapsedSections()
    }
}

// MARK: - Section Header

struct AnalyticsSectionHeader<Accessory: View>: View {
    let title: LocalizedStringKey
    var isCollapsible: Bool = false
    var isExpanded: Bool = true
    var onToggle: (() -> Void)?
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        let context = SectionHeaderContext(title: title, isCollapsible: isCollapsible, isExpanded: isExpanded)
        HStack(spacing: 10.0) {
            toggleWrapper {
                HStack(spacing: 10.0) {
                    Text(context.title)
                        .sectionHeaderTitle()
                        .layoutPriority(1)
                    Rectangle()
                        .fill(Color.hairline)
                        .frame(height: 1.0)
                }
                .contentShape(.rect)
            }
            accessory()
            if isCollapsible {
                toggleWrapper {
                    SectionChevron(context: context)
                        .contentShape(.rect)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 6.0)
        .padding(.bottom, 4.0)
    }

    @ViewBuilder
    private func toggleWrapper<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if isCollapsible, let onToggle {
            Button(action: onToggle) {
                content()
            }
            .buttonStyle(.plain)
        } else {
            content()
        }
    }
}

struct AnalyticsCardGrid<Item: Hashable, Content: View>: View {
    let items: [Item]
    let columns: Int
    let spacing: CGFloat
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        if columns <= 1 {
            VStack(spacing: spacing) {
                ForEach(items, id: \.self) { item in
                    content(item)
                }
            }
        } else {
            let rowCount = (items.count + columns - 1) / columns
            VStack(spacing: spacing) {
                ForEach(0..<rowCount, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<columns, id: \.self) { col in
                            let index = row * columns + col
                            if index < items.count {
                                content(items[index])
                                    .id(items[index])
                                    .frame(maxWidth: .infinity)
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
    }
}

extension AnalyticsSectionHeader where Accessory == EmptyView {
    init(
        title: LocalizedStringKey,
        isCollapsible: Bool = false,
        isExpanded: Bool = true,
        onToggle: (() -> Void)? = nil
    ) {
        self.title = title
        self.isCollapsible = isCollapsible
        self.isExpanded = isExpanded
        self.onToggle = onToggle
        self.accessory = { EmptyView() }
    }
}

// MARK: - Drag-and-Drop View Extensions

extension View {
    @ViewBuilder
    func editableCard(
        isVisible: Bool,
        isEditing: Bool,
        seed: Int,
        cornerRadius: CGFloat = 20.0,
        onToggle: @escaping () -> Void
    ) -> some View {
        self
            .opacity(isEditing && !isVisible ? 0.4 : 1.0)
            .overlay {
                if isEditing && !isVisible {
                    Image(systemName: "eye.slash.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .shadow(radius: 3.0)
                }
            }
            .overlay {
                if isEditing {
                    Color.white.opacity(0.001)
                        .contentShape(.rect(cornerRadius: cornerRadius))
                        .onTapGesture { onToggle() }
                }
            }
            .jiggle(isActive: isEditing, seed: seed)
    }
}

extension View {
    @ViewBuilder
    func cardDraggable(
        _ cardType: AnalyticsCardType,
        editing: Bool,
        draggedCard: Binding<AnalyticsCardType?>,
        cardOrder: Binding<[AnalyticsCardType]>,
        onReorder: @escaping () -> Void
    ) -> some View {
        if editing {
            self
                .opacity(draggedCard.wrappedValue == cardType ? 0.4 : 1.0)
                .onDrag {
                    draggedCard.wrappedValue = cardType
                    return NSItemProvider(object: cardType.rawValue as NSString)
                }
                .onDrop(of: [.text], delegate: CardReorderDropDelegate(
                    target: cardType,
                    cards: cardOrder,
                    draggedCard: draggedCard,
                    onReorder: onReorder
                ))
        } else {
            self
        }
    }

    @ViewBuilder
    func perLevelCardDraggable(
        _ card: PerLevelCardID,
        editing: Bool,
        draggedCard: Binding<PerLevelCardID?>,
        cardOrder: Binding<[PerLevelCardID]>,
        onReorder: @escaping () -> Void
    ) -> some View {
        if editing {
            self
                .opacity(draggedCard.wrappedValue == card ? 0.4 : 1.0)
                .onDrag {
                    draggedCard.wrappedValue = card
                    return NSItemProvider(object: card.dragIdentifier as NSString)
                }
                .onDrop(of: [.text], delegate: PerLevelCardReorderDropDelegate(
                    target: card,
                    cards: cardOrder,
                    draggedCard: draggedCard,
                    onReorder: onReorder
                ))
        } else {
            self
        }
    }
}
