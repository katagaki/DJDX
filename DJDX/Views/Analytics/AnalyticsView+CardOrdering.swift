//
//  AnalyticsView+CardOrdering.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Card Ordering & Persistence

extension AnalyticsView {

    func loadCardOrder() {
        if let decoded = try? JSONDecoder().decode([AnalyticsCardType].self, from: cardOrderData),
           !decoded.isEmpty {
            var order = decoded
            for cardType in AnalyticsCardType.defaultOrder where !order.contains(cardType) {
                order.append(cardType)
            }
            order.removeAll { !AnalyticsCardType.defaultOrder.contains($0) }
            cardOrder = order
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
        withAnimation(.snappy) {
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

struct AnalyticsSectionHeader: View {
    let title: LocalizedStringKey
    var isCollapsible: Bool = false
    var isExpanded: Bool = true
    var onToggle: (() -> Void)?

    var body: some View {
        if isCollapsible, let onToggle {
            Button(action: onToggle) {
                headerContent
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        } else {
            headerContent
        }
    }

    @ViewBuilder
    var headerContent: some View {
        HStack(spacing: 6.0) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.primary)
            if isCollapsible {
                Image(systemName: "chevron.down")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 0.0 : -90.0))
            }
            Spacer()
        }
        .padding(.horizontal)
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
