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

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedCard = nil
        return true
    }

    func dropEntered(info: DropInfo) {
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

    func dropExited(info: DropInfo) {}
}

struct LevelReorderDropDelegate: DropDelegate {
    let target: Int
    @Binding var levels: [Int]
    @Binding var draggedLevel: Int?
    let onReorder: () -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedLevel = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedLevel, draggedLevel != target else { return }
        guard let fromIndex = levels.firstIndex(of: draggedLevel),
              let toIndex = levels.firstIndex(of: target) else { return }

        withAnimation(.snappy(duration: 0.3)) {
            levels.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
        onReorder()
    }

    func dropExited(info: DropInfo) {}
}
