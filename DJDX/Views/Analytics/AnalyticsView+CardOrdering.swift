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
            var cards = decoded
            for cardType in AnalyticsCardType.allCases where !decoded.contains(cardType) {
                cards.insert(cardType)
            }
            visibleCards = cards
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
}

// MARK: - Drag-and-Drop View Extensions

extension View {
    @ViewBuilder
    func cardDraggable(
        _ cardType: AnalyticsCardType,
        editing: Bool,
        draggedCard: Binding<AnalyticsCardType?>,
        cardOrder: Binding<[AnalyticsCardType]>,
        onReorder: @escaping () -> Void
    ) -> some View {
        let seed = cardOrder.wrappedValue.firstIndex(of: cardType) ?? 0
        if editing {
            self
                .jiggle(isActive: true, seed: seed)
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
        let seed = card.difficulty * 10 +
            (AnalyticsPerLevelCategory.allCases.firstIndex(of: card.category) ?? 0)
        if editing {
            self
                .jiggle(isActive: true, seed: seed)
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
