import SwiftUI

enum GITADORAAnalyticsCard: String, Codable, Hashable, CaseIterable {
    case skill
    case clearBreakdown
    case rankBreakdown
    case newHighScores
    case newRankSS
    case newRankS
    case newClearClear
    case newClearFullCombo
    case newClearExcellent

    static var defaultOrder: [GITADORAAnalyticsCard] { allCases }

    static var defaultVisible: Set<GITADORAAnalyticsCard> { Set(allCases) }

    var section: AnalyticsSection {
        switch self {
        case .skill, .clearBreakdown, .rankBreakdown: return .overview
        default: return .lastPlay
        }
    }

    var clearType: String? {
        switch self {
        case .newClearClear: return GITADORAClearType.clear.rawValue
        case .newClearFullCombo: return GITADORAClearType.fullCombo.rawValue
        case .newClearExcellent: return GITADORAClearType.excellent.rawValue
        default: return nil
        }
    }

    var rank: String? {
        switch self {
        case .newRankSS: return GITADORARank.ss.rawValue
        case .newRankS: return GITADORARank.s.rawValue
        default: return nil
        }
    }

    var destination: GITADORAAnalyticsPath? {
        switch self {
        case .skill: return .skillDetail
        case .clearBreakdown: return .clearBreakdownDetail
        case .rankBreakdown: return .rankBreakdownDetail
        case .newHighScores: return .newHighScoresDetail
        default:
            if let clearType { return .newClearsDetail(clearType: clearType) }
            if let rank { return .newRanksDetail(rank: rank) }
            return nil
        }
    }

    var transitionID: String { "GITADORA.\(rawValue)" }

    var systemImage: String {
        switch self {
        case .skill: return "guitars"
        case .clearBreakdown, .rankBreakdown: return "chart.bar"
        case .newHighScores: return "trophy"
        case .newClearClear: return "checkmark.circle"
        case .newClearFullCombo: return "star.circle"
        case .newClearExcellent: return "star.circle.fill"
        case .newRankSS, .newRankS: return "crown"
        }
    }

    var iconColor: Color {
        if self == .newHighScores { return .primary }
        if let clearType { return GITADORAClearType(rawValue: clearType)?.color ?? .gray }
        return .orange
    }

    var titleText: Text {
        switch self {
        case .newHighScores: return Text("Analytics.NewHighScores")
        default:
            if let clearType {
                return Text(verbatim: GITADORAClearType(rawValue: clearType)?.abbreviation ?? clearType)
            }
            if let rank { return Text(verbatim: rank) }
            return Text(verbatim: "")
        }
    }
}

extension View {
    @ViewBuilder
    func gitadoraCardDraggable(
        _ cardType: GITADORAAnalyticsCard,
        editing: Bool,
        draggedCard: Binding<GITADORAAnalyticsCard?>,
        cardOrder: Binding<[GITADORAAnalyticsCard]>,
        onReorder: @escaping () -> Void
    ) -> some View {
        if editing {
            self
                .opacity(draggedCard.wrappedValue == cardType ? 0.4 : 1.0)
                .onDrag {
                    draggedCard.wrappedValue = cardType
                    return NSItemProvider(object: cardType.rawValue as NSString)
                }
                .onDrop(of: [.text], delegate: GITADORACardReorderDropDelegate(
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

struct GITADORACardReorderDropDelegate: DropDelegate {
    let target: GITADORAAnalyticsCard
    @Binding var cards: [GITADORAAnalyticsCard]
    @Binding var draggedCard: GITADORAAnalyticsCard?
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

    func dropExited(info _: DropInfo) {}
}
