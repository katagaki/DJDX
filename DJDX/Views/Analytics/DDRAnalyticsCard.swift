import SwiftUI

enum DDRAnalyticsPath: Hashable {
    case clearBreakdownDetail
    case rankBreakdownDetail
}

enum DDRAnalyticsCard: String, Codable, Hashable, CaseIterable {
    case clearBreakdown
    case rankBreakdown

    static var defaultOrder: [DDRAnalyticsCard] { allCases }

    static var defaultVisible: Set<DDRAnalyticsCard> { Set(allCases) }

    var section: AnalyticsSection { .overview }

    var destination: DDRAnalyticsPath? {
        switch self {
        case .clearBreakdown: return .clearBreakdownDetail
        case .rankBreakdown: return .rankBreakdownDetail
        }
    }

    var transitionID: String { "DDR.\(rawValue)" }
}

extension View {
    @ViewBuilder
    func ddrCardDraggable(
        _ cardType: DDRAnalyticsCard,
        editing: Bool,
        draggedCard: Binding<DDRAnalyticsCard?>,
        cardOrder: Binding<[DDRAnalyticsCard]>,
        onReorder: @escaping () -> Void
    ) -> some View {
        if editing {
            self
                .opacity(draggedCard.wrappedValue == cardType ? 0.4 : 1.0)
                .onDrag {
                    draggedCard.wrappedValue = cardType
                    return NSItemProvider(object: cardType.rawValue as NSString)
                }
                .onDrop(of: [.text], delegate: DDRCardReorderDropDelegate(
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

struct DDRCardReorderDropDelegate: DropDelegate {
    let target: DDRAnalyticsCard
    @Binding var cards: [DDRAnalyticsCard]
    @Binding var draggedCard: DDRAnalyticsCard?
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
        guard draggedCard.section == target.section else { return }
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
    }
}
