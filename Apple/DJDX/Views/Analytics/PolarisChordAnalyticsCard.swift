import SwiftUI

enum PolarisChordAnalyticsCard: String, Codable, Hashable, CaseIterable {
    case clearBreakdown
    case gradeBreakdown
    case newHighScores
    case newGradeSSSPlus
    case newGradeSSS
    case newGradeSS
    case newGradeS
    case newClearSuccess
    case newClearFullCombo
    case newClearAllPerfect

    static var defaultOrder: [PolarisChordAnalyticsCard] { allCases }

    static var defaultVisible: Set<PolarisChordAnalyticsCard> { Set(allCases) }

    var section: AnalyticsSection {
        switch self {
        case .clearBreakdown, .gradeBreakdown: return .overview
        default: return .lastPlay
        }
    }

    /// Clear-type rawValue surfaced by a "new clear" card, if any.
    var clearType: String? {
        switch self {
        case .newClearSuccess: return PolarisChordClearType.success.rawValue
        case .newClearFullCombo: return PolarisChordClearType.fullCombo.rawValue
        case .newClearAllPerfect: return PolarisChordClearType.allPerfect.rawValue
        default: return nil
        }
    }

    /// Grade rawValue surfaced by a "new grade" card, if any.
    var grade: String? {
        switch self {
        case .newGradeSSSPlus: return PolarisChordGrade.sssPlus.rawValue
        case .newGradeSSS: return PolarisChordGrade.sss.rawValue
        case .newGradeSS: return PolarisChordGrade.ss.rawValue
        case .newGradeS: return PolarisChordGrade.s.rawValue
        default: return nil
        }
    }

    var destination: PolarisChordAnalyticsPath? {
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

    var transitionID: String { "PolarisChord.\(rawValue)" }

    var systemImage: String {
        switch self {
        case .clearBreakdown, .gradeBreakdown: return "chart.bar"
        case .newHighScores: return "trophy"
        case .newClearSuccess: return "checkmark.circle"
        case .newClearFullCombo: return "star.circle"
        case .newClearAllPerfect: return "star.circle.fill"
        case .newGradeSSSPlus, .newGradeSSS, .newGradeSS, .newGradeS: return "crown"
        }
    }

    var iconColor: Color {
        // NEW RECORD uses the primary color (white/black per appearance).
        if self == .newHighScores { return .primary }
        if let clearType { return PolarisChordClearType(rawValue: clearType)?.color ?? .gray }
        return .orange
    }

    var titleText: Text {
        switch self {
        case .newHighScores: return Text("Analytics.NewHighScores")
        default:
            if let clearType {
                return Text(verbatim: PolarisChordClearType(rawValue: clearType)?.abbreviation ?? clearType)
            }
            if let grade { return Text(verbatim: grade) }
            return Text(verbatim: "")
        }
    }
}

extension View {
    @ViewBuilder
    func polarisChordCardDraggable(
        _ cardType: PolarisChordAnalyticsCard,
        editing: Bool,
        draggedCard: Binding<PolarisChordAnalyticsCard?>,
        cardOrder: Binding<[PolarisChordAnalyticsCard]>,
        onReorder: @escaping () -> Void
    ) -> some View {
        if editing {
            self
                .opacity(draggedCard.wrappedValue == cardType ? 0.4 : 1.0)
                .onDrag {
                    draggedCard.wrappedValue = cardType
                    return NSItemProvider(object: cardType.rawValue as NSString)
                }
                .onDrop(of: [.text], delegate: PolarisChordCardReorderDropDelegate(
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

struct PolarisChordCardReorderDropDelegate: DropDelegate {
    let target: PolarisChordAnalyticsCard
    @Binding var cards: [PolarisChordAnalyticsCard]
    @Binding var draggedCard: PolarisChordAnalyticsCard?
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
