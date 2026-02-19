//
//  AnalyticsDropDelegates.swift
//  DJDX
//
//  Created on 2026/02/19.
//

import SwiftUI
import UniformTypeIdentifiers

struct CardReorderDropDelegate: DropDelegate {
    let target: AnalyticsCardType
    @Binding var cards: [AnalyticsCardType]
    @Binding var draggedCard: AnalyticsCardType?
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

        let pinnedCount = cards.prefix(while: { $0.isPinned }).count
        guard toIndex >= pinnedCount else { return }

        withAnimation(.snappy(duration: 0.3)) {
            cards.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
        onReorder()
    }

    func dropExited(info _: DropInfo) {}
}

struct PerLevelCardID: Codable, Hashable {
    let difficulty: Int
    let category: AnalyticsPerLevelCategory

    var dragIdentifier: String {
        "\(difficulty)_\(category.rawValue)"
    }

    static var defaultOrder: [PerLevelCardID] {
        var order: [PerLevelCardID] = []
        for difficulty in 1...12 {
            for category in AnalyticsPerLevelCategory.allCases {
                order.append(PerLevelCardID(difficulty: difficulty, category: category))
            }
        }
        return order
    }

    static var defaultVisible: Set<PerLevelCardID> {
        var cards: Set<PerLevelCardID> = []
        for difficulty in [1, 12] {
            for category in AnalyticsPerLevelCategory.defaultVisible {
                cards.insert(PerLevelCardID(difficulty: difficulty, category: category))
            }
        }
        return cards
    }
}

struct PerLevelCardReorderDropDelegate: DropDelegate {
    let target: PerLevelCardID
    @Binding var cards: [PerLevelCardID]
    @Binding var draggedCard: PerLevelCardID?
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

    func dropExited(info _: DropInfo) {}
}
