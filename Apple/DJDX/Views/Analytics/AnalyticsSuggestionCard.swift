import SwiftUI

enum AnalyticsSuggestionCardID: String, Codable, Hashable, CaseIterable {
    case iidxDJLevel
    case iidxClearLamp
    case iidxNotPlayedRecently
    case sdvxVolforce
    case ddrFlareSkill

    static let iidxCards: [AnalyticsSuggestionCardID] = [.iidxDJLevel, .iidxClearLamp, .iidxNotPlayedRecently]
    static let sdvxCards: [AnalyticsSuggestionCardID] = [.sdvxVolforce]
    static let ddrCards: [AnalyticsSuggestionCardID] = [.ddrFlareSkill]

    var transitionID: String { "Suggestions.\(rawValue)" }
}

struct AnalyticsSuggestionsSection<Card: View>: View {

    let cards: [AnalyticsSuggestionCardID]
    let columns: [GridItem]
    let isEditing: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let card: (AnalyticsSuggestionCardID) -> Card

    @AppStorage(wrappedValue: Data(), "Analytics.Suggestions.CardOrder") var cardOrderData: Data
    @AppStorage(wrappedValue: Data(), "Analytics.Suggestions.HiddenCards") var hiddenCardsData: Data
    @State var cardOrder: [AnalyticsSuggestionCardID] = AnalyticsSuggestionCardID.allCases
    @State var hiddenCards: Set<AnalyticsSuggestionCardID> = []
    @State var draggedCard: AnalyticsSuggestionCardID?

    var orderedCards: [AnalyticsSuggestionCardID] {
        cardOrder.filter { cards.contains($0) }
    }

    var body: some View {
        let shownCards = isEditing ? orderedCards : orderedCards.filter { !hiddenCards.contains($0) }
        Group {
            if !shownCards.isEmpty {
                VStack(spacing: 12.0) {
                    AnalyticsSectionHeader(
                        title: AnalyticsSection.suggestions.titleKey,
                        isCollapsible: !isEditing,
                        isExpanded: isEditing || isExpanded,
                        onToggle: onToggle
                    )
                    if isEditing || isExpanded {
                        LazyVGrid(columns: columns, spacing: 12.0) {
                            ForEach(shownCards, id: \.self) { cardID in
                                card(cardID)
                                    .editableCard(isVisible: !hiddenCards.contains(cardID),
                                                  isEditing: isEditing,
                                                  seed: (cardOrder.firstIndex(of: cardID) ?? 0) + 100) {
                                        toggle(cardID)
                                    }
                                    .suggestionCardDraggable(cardID, editing: isEditing,
                                                             draggedCard: $draggedCard, cardOrder: $cardOrder,
                                                             onReorder: save)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .onAppear(perform: load)
        .onReceive(NotificationCenter.default.publisher(for: .analyticsLayoutReset)) { _ in
            withAnimation(.smooth.speed(2.0)) {
                cardOrder = AnalyticsSuggestionCardID.allCases
                hiddenCards = []
            }
            save()
        }
    }

    func toggle(_ cardID: AnalyticsSuggestionCardID) {
        withAnimation(.smooth.speed(2.0)) {
            if hiddenCards.contains(cardID) {
                hiddenCards.remove(cardID)
            } else {
                hiddenCards.insert(cardID)
            }
        }
        save()
    }

    func load() {
        if let decoded = try? JSONDecoder().decode([AnalyticsSuggestionCardID].self, from: cardOrderData) {
            var order = decoded.filter { AnalyticsSuggestionCardID.allCases.contains($0) }
            for (index, cardID) in AnalyticsSuggestionCardID.allCases.enumerated() where !order.contains(cardID) {
                if index > 0,
                   let predecessorIndex = order.firstIndex(of: AnalyticsSuggestionCardID.allCases[index - 1]) {
                    order.insert(cardID, at: predecessorIndex + 1)
                } else {
                    order.append(cardID)
                }
            }
            cardOrder = order
        }
        if let decoded = try? JSONDecoder().decode(Set<AnalyticsSuggestionCardID>.self, from: hiddenCardsData) {
            hiddenCards = decoded
        }
    }

    func save() {
        cardOrderData = (try? JSONEncoder().encode(cardOrder)) ?? Data()
        hiddenCardsData = (try? JSONEncoder().encode(hiddenCards)) ?? Data()
    }
}

extension View {
    @ViewBuilder
    func suggestionCardDraggable(
        _ cardID: AnalyticsSuggestionCardID,
        editing: Bool,
        draggedCard: Binding<AnalyticsSuggestionCardID?>,
        cardOrder: Binding<[AnalyticsSuggestionCardID]>,
        onReorder: @escaping () -> Void
    ) -> some View {
        if editing {
            self
                .opacity(draggedCard.wrappedValue == cardID ? 0.4 : 1.0)
                .onDrag {
                    draggedCard.wrappedValue = cardID
                    return NSItemProvider(object: cardID.rawValue as NSString)
                }
                .onDrop(of: [.text], delegate: SuggestionCardReorderDropDelegate(
                    target: cardID,
                    cards: cardOrder,
                    draggedCard: draggedCard,
                    onReorder: onReorder
                ))
        } else {
            self
        }
    }
}

struct SuggestionCardReorderDropDelegate: DropDelegate {
    let target: AnalyticsSuggestionCardID
    @Binding var cards: [AnalyticsSuggestionCardID]
    @Binding var draggedCard: AnalyticsSuggestionCardID?
    let onReorder: () -> Void

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info _: DropInfo) -> Bool {
        draggedCard = nil
        return true
    }

    func dropEntered(info _: DropInfo) {
        guard let draggedCard, draggedCard != target,
              let fromIndex = cards.firstIndex(of: draggedCard),
              let toIndex = cards.firstIndex(of: target) else { return }
        withAnimation(.snappy(duration: 0.3)) {
            cards.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
        onReorder()
    }
}

struct AnalyticsSuggestionCard<Item: Identifiable, Row: View>: View {

    let title: Text
    let systemImage: String
    let iconColor: Color
    let items: [Item]
    @ViewBuilder let row: (Item) -> Row

    static var previewLimit: Int { 3 }

    var cornerRadius: CGFloat {
        if #available(iOS 26.0, *) {
            return 20.0
        } else {
            return 12.0
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0.0) {
            HStack(spacing: 5.0) {
                Image(systemName: systemImage)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(iconColor)
                    .frame(width: 12.0, height: 12.0)
                title
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0.0)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12.0)
            if items.isEmpty {
                Text("Analytics.Suggestions.Empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120.0, alignment: .center)
            } else {
                ForEach(Array(items.prefix(Self.previewLimit))) { item in
                    Divider()
                    row(item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .cardBackground(cornerRadius: cornerRadius)
    }
}

struct AnalyticsSuggestionList<Item: Identifiable, Row: View>: View {
    let items: [Item]
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0.0) {
                if items.isEmpty {
                    Text("Analytics.Suggestions.Empty")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24.0)
                } else {
                    ForEach(items) { item in
                        row(item)
                        Divider()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

struct AnalyticsSuggestionTarget<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 6.0) {
            Image(systemName: "arrow.turn.down.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            content
        }
        .offset(y: 1.0)
    }
}

struct AnalyticsSuggestionGain: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .foregroundStyle(.orange)
            .font(.scoreline(.caption))
            .fontWidth(.standard)
    }
}
