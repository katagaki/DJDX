import SwiftUI

enum SDVXAnalyticsCard: String, Codable, Hashable, CaseIterable {
    case clearBreakdown
    case gradeBreakdown
    case newHighScores
    case newClearComplete
    case newClearExcessive
    case newClearUltimateChain
    case newClearPerfectUC
    case newGradeS
    case newGradeAAAPlus
    case newGradeAAA
    case newGradeAAPlus
    case newGradeAA
    case newGradeAPlus
    case newGradeA

    static var defaultOrder: [SDVXAnalyticsCard] { allCases }

    static var defaultVisible: Set<SDVXAnalyticsCard> {
        [
            .clearBreakdown, .gradeBreakdown,
            .newHighScores,
            .newClearComplete, .newClearExcessive,
            .newClearUltimateChain, .newClearPerfectUC,
            .newGradeS, .newGradeAAAPlus, .newGradeAAA
        ]
    }

    var section: AnalyticsSection {
        switch self {
        case .clearBreakdown, .gradeBreakdown: return .overview
        default: return .lastPlay
        }
    }

    /// Clear-rank rawValue surfaced by a "new clear" card, if any.
    var clearType: String? {
        switch self {
        case .newClearComplete: return SDVXClearType.complete.rawValue
        case .newClearExcessive: return SDVXClearType.excessive.rawValue
        case .newClearUltimateChain: return SDVXClearType.ultimateChain.rawValue
        case .newClearPerfectUC: return SDVXClearType.perfectUltimateChain.rawValue
        default: return nil
        }
    }

    /// Grade rawValue surfaced by a "new grade" card, if any.
    var grade: String? {
        switch self {
        case .newGradeS: return SDVXGrade.s.rawValue
        case .newGradeAAAPlus: return SDVXGrade.aaaPlus.rawValue
        case .newGradeAAA: return SDVXGrade.aaa.rawValue
        case .newGradeAAPlus: return SDVXGrade.aaPlus.rawValue
        case .newGradeAA: return SDVXGrade.aa.rawValue
        case .newGradeAPlus: return SDVXGrade.aPlus.rawValue
        case .newGradeA: return SDVXGrade.a.rawValue
        default: return nil
        }
    }

    var destination: SDVXAnalyticsPath? {
        switch self {
        case .clearBreakdown: return .clearBreakdownDetail
        case .gradeBreakdown: return .gradeBreakdownDetail
        case .newHighScores: return .newHighScoresDetail
        default:
            if let clearType { return .newClearsDetail(clearType: clearType) }
            if let grade { return .newGradesDetail(grade: grade) }
            return nil
        }
    }

    var transitionID: String { "SDVX.\(rawValue)" }

    var systemImage: String {
        switch self {
        case .clearBreakdown: return "chart.bar"
        case .gradeBreakdown: return "chart.bar"
        case .newHighScores: return "trophy"
        case .newClearComplete, .newClearExcessive,
             .newClearUltimateChain, .newClearPerfectUC: return "checkmark.circle"
        case .newGradeS, .newGradeAAAPlus, .newGradeAAA,
             .newGradeAAPlus, .newGradeAA, .newGradeAPlus, .newGradeA: return "crown"
        }
    }

    var iconColor: Color {
        // NEW RECORD uses the primary color (white/black per appearance).
        if self == .newHighScores { return .primary }
        if let clearType { return SDVXClearType(rawValue: clearType)?.color ?? .gray }
        return .orange
    }

    var titleText: Text {
        switch self {
        case .newHighScores: return Text("Analytics.NewHighScores")
        default:
            if let clearType {
                return Text(verbatim: SDVXClearType(rawValue: clearType)?.abbreviation ?? clearType)
            }
            if let grade { return Text(verbatim: grade) }
            return Text(verbatim: "")
        }
    }
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
