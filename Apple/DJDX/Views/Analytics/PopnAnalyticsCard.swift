import SwiftUI

enum PopnAnalyticsCard: String, Codable, Hashable, CaseIterable {
    case popnClass
    case medalBreakdown
    case rankBreakdown
    case newHighScores
    case newRankS
    case newRankAAA
    case newRankAA
    case newClearClear
    case newClearFullCombo
    case newClearPerfect

    static var defaultOrder: [PopnAnalyticsCard] { allCases }

    static var defaultVisible: Set<PopnAnalyticsCard> { Set(allCases) }

    var section: AnalyticsSection {
        switch self {
        case .popnClass, .medalBreakdown, .rankBreakdown: return .overview
        default: return .lastPlay
        }
    }

    var clearType: String? {
        switch self {
        case .newClearClear: return PopnClearType.clear.rawValue
        case .newClearFullCombo: return PopnClearType.fullCombo.rawValue
        case .newClearPerfect: return PopnClearType.perfect.rawValue
        default: return nil
        }
    }

    var rank: String? {
        switch self {
        case .newRankS: return PopnRank.s.rawValue
        case .newRankAAA: return PopnRank.aaa.rawValue
        case .newRankAA: return PopnRank.aa.rawValue
        default: return nil
        }
    }

    var destination: PopnAnalyticsPath? {
        switch self {
        case .popnClass: return .popnClassDetail
        case .medalBreakdown: return .medalBreakdownDetail
        case .rankBreakdown: return .rankBreakdownDetail
        case .newHighScores: return .newHighScoresDetail
        default:
            if let clearType { return .newClearsDetail(clearType: clearType) }
            if let rank { return .newRanksDetail(rank: rank) }
            return nil
        }
    }

    var transitionID: String { "Popn.\(rawValue)" }

    var systemImage: String {
        switch self {
        case .popnClass, .medalBreakdown, .rankBreakdown: return "chart.bar"
        case .newHighScores: return "trophy"
        case .newClearClear: return "checkmark.circle"
        case .newClearFullCombo: return "star.circle"
        case .newClearPerfect: return "star.circle.fill"
        case .newRankS, .newRankAAA, .newRankAA: return "crown"
        }
    }

    var iconColor: Color {
        if self == .newHighScores { return .primary }
        if let clearType { return PopnClearType(rawValue: clearType)?.color ?? .gray }
        return .orange
    }

    var titleText: Text {
        switch self {
        case .newHighScores: return Text("Analytics.NewHighScores")
        default:
            if let clearType {
                return Text(verbatim: PopnClearType(rawValue: clearType)?.abbreviation ?? clearType)
            }
            if let rank { return Text(verbatim: rank) }
            return Text(verbatim: "")
        }
    }
}

extension View {
    @ViewBuilder
    func popnCardDraggable(
        _ cardType: PopnAnalyticsCard,
        editing: Bool,
        draggedCard: Binding<PopnAnalyticsCard?>,
        cardOrder: Binding<[PopnAnalyticsCard]>,
        onReorder: @escaping () -> Void
    ) -> some View {
        if editing {
            self
                .opacity(draggedCard.wrappedValue == cardType ? 0.4 : 1.0)
                .onDrag {
                    draggedCard.wrappedValue = cardType
                    return NSItemProvider(object: cardType.rawValue as NSString)
                }
                .onDrop(of: [.text], delegate: PopnCardReorderDropDelegate(
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

struct PopnCardReorderDropDelegate: DropDelegate {
    let target: PopnAnalyticsCard
    @Binding var cards: [PopnAnalyticsCard]
    @Binding var draggedCard: PopnAnalyticsCard?
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
        // Only reorder within the same section so cards can't jump between sections.
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
        // No cleanup needed when a drag leaves this target
    }
}
