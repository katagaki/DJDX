import SwiftUI

enum AnalyticsSuggestionCardID: String, Codable, Hashable, CaseIterable, Identifiable {
    case iidxDJLevel
    case iidxAlmostFullCombo
    case iidxAlmostExHard
    case iidxAlmostHard
    case iidxAlmostClear
    case iidxAlmostEasy
    case iidxAlmostAssist
    case iidxNotPlayedRecently
    case sdvxVolforce
    case ddrFlareSkill

    var id: Self { self }

    static let iidxClearLampCards: [AnalyticsSuggestionCardID] = [
        .iidxAlmostFullCombo, .iidxAlmostExHard, .iidxAlmostHard,
        .iidxAlmostClear, .iidxAlmostEasy, .iidxAlmostAssist
    ]
    static let iidxCards: [AnalyticsSuggestionCardID] = [.iidxDJLevel] + iidxClearLampCards + [.iidxNotPlayedRecently]
    static let sdvxCards: [AnalyticsSuggestionCardID] = [.sdvxVolforce]
    static let ddrCards: [AnalyticsSuggestionCardID] = [.ddrFlareSkill]
    static let hiddenCardsKey = "Analytics.Suggestions.HiddenCards.v2"
    static let sectionLimit = 20
    static let defaultHidden: Set<AnalyticsSuggestionCardID> = [
        .iidxAlmostFullCombo, .iidxAlmostExHard, .iidxAlmostClear, .iidxAlmostEasy, .iidxAlmostAssist
    ]

    var targetClearType: IIDXClearType? {
        switch self {
        case .iidxAlmostFullCombo: .fullComboClear
        case .iidxAlmostExHard: .exHardClear
        case .iidxAlmostHard: .hardClear
        case .iidxAlmostClear: .clear
        case .iidxAlmostEasy: .easyClear
        case .iidxAlmostAssist: .assistClear
        default: nil
        }
    }

    static func clearLampID(for target: IIDXClearType) -> AnalyticsSuggestionCardID {
        switch target {
        case .fullComboClear: .iidxAlmostFullCombo
        case .exHardClear: .iidxAlmostExHard
        case .hardClear: .iidxAlmostHard
        case .clear: .iidxAlmostClear
        case .easyClear: .iidxAlmostEasy
        case .assistClear: .iidxAlmostAssist
        default: .iidxAlmostHard
        }
    }

    static func decodedHidden(from data: Data) -> Set<AnalyticsSuggestionCardID> {
        if !data.isEmpty, let decoded = try? JSONDecoder().decode(Set<AnalyticsSuggestionCardID>.self, from: data) {
            return decoded
        }
        return migratedLegacyHidden()
    }

    static func encodedHidden(_ set: Set<AnalyticsSuggestionCardID>) -> Data {
        (try? JSONEncoder().encode(set)) ?? Data()
    }

    private static func migratedLegacyHidden() -> Set<AnalyticsSuggestionCardID> {
        let defaults = UserDefaults.standard
        let activeClearLamp: AnalyticsSuggestionCardID
        if let rawTarget = defaults.string(forKey: "Analytics.Suggestions.TargetClearType"),
           let target = IIDXClearType(rawValue: rawTarget) {
            activeClearLamp = clearLampID(for: target)
        } else {
            activeClearLamp = .iidxAlmostHard
        }
        var hidden = Set(iidxClearLampCards)
        hidden.remove(activeClearLamp)
        if let legacyData = defaults.data(forKey: "Analytics.Suggestions.HiddenCards"),
           let legacyRaw = try? JSONDecoder().decode([String].self, from: legacyData) {
            for raw in legacyRaw {
                if raw == "iidxClearLamp" {
                    hidden.formUnion(iidxClearLampCards)
                } else if let id = AnalyticsSuggestionCardID(rawValue: raw) {
                    hidden.insert(id)
                }
            }
        }
        return hidden
    }
}

struct AnalyticsSuggestionsSection<Content: View>: View {
    let cards: [AnalyticsSuggestionCardID]
    let title: (AnalyticsSuggestionCardID) -> LocalizedStringKey
    let canShare: (AnalyticsSuggestionCardID) -> Bool
    let onShare: (AnalyticsSuggestionCardID) -> Void
    @ViewBuilder let content: (AnalyticsSuggestionCardID) -> Content

    @AppStorage(wrappedValue: Data(), AnalyticsSuggestionCardID.hiddenCardsKey) var hiddenCardsData: Data
    @AppStorage(wrappedValue: Data(), "Analytics.Suggestions.CollapsedCards") var collapsedCardsData: Data
    @State var hiddenCards: Set<AnalyticsSuggestionCardID> = AnalyticsSuggestionCardID.defaultHidden
    @State var collapsedCards: Set<AnalyticsSuggestionCardID> = []

    var body: some View {
        let shownCards = cards.filter { !hiddenCards.contains($0) }
        Group {
            if !shownCards.isEmpty {
                VStack(spacing: DesignMetrics.sectionGap) {
                    ForEach(shownCards, id: \.self) { cardID in
                        let isExpanded = !collapsedCards.contains(cardID)
                        VStack(spacing: 0.0) {
                            AnalyticsSectionHeader(
                                title: title(cardID),
                                isCollapsible: true,
                                isExpanded: isExpanded,
                                onToggle: { toggleCollapsed(cardID) }
                            ) {
                                if canShare(cardID) {
                                    Button("ShareCard.Title", systemImage: "square.and.arrow.up") {
                                        onShare(cardID)
                                    }
                                    .labelStyle(.iconOnly)
                                    .font(.subheadline.weight(.bold))
                                }
                            }
                            .padding(.bottom, isExpanded ? 8.0 : 0.0)
                            if isExpanded {
                                content(cardID)
                            }
                        }
                    }
                }
                .padding(.top, DesignMetrics.sectionGap)
            }
        }
        .onAppear(perform: load)
        .onChange(of: hiddenCardsData) { _, _ in
            withAnimation(.smooth.speed(2.0)) {
                hiddenCards = AnalyticsSuggestionCardID.decodedHidden(from: hiddenCardsData)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .analyticsLayoutReset)) { _ in
            withAnimation(.smooth.speed(2.0)) {
                hiddenCards = AnalyticsSuggestionCardID.defaultHidden
                collapsedCards = []
            }
            hiddenCardsData = AnalyticsSuggestionCardID.encodedHidden(hiddenCards)
            saveCollapsed()
        }
    }

    func toggleCollapsed(_ cardID: AnalyticsSuggestionCardID) {
        withAnimation(.smooth.speed(2.0)) {
            if collapsedCards.contains(cardID) {
                collapsedCards.remove(cardID)
            } else {
                collapsedCards.insert(cardID)
            }
        }
        saveCollapsed()
    }

    func load() {
        hiddenCards = AnalyticsSuggestionCardID.decodedHidden(from: hiddenCardsData)
        if let decoded = try? JSONDecoder().decode(Set<AnalyticsSuggestionCardID>.self, from: collapsedCardsData) {
            collapsedCards = decoded
        }
    }

    func saveCollapsed() {
        collapsedCardsData = (try? JSONEncoder().encode(collapsedCards)) ?? Data()
    }
}

struct AnalyticsSuggestionPreviewRows<Item: Identifiable, Row: View>: View {
    let items: [Item]
    var limit: Int = AnalyticsSuggestionCardID.sectionLimit
    let onSelect: (Item) -> Void
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        VStack(spacing: 0.0) {
            Divider()
            if items.isEmpty {
                Text("Analytics.Suggestions.Empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: DesignMetrics.emptyCardHeight, alignment: .center)
                Divider()
            } else {
                ForEach(Array(items.prefix(limit))) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        row(item)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
    }
}

struct AnalyticsSuggestionTarget<Content: View>: View {
    var isInline: Bool = false
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .center, spacing: isInline ? 4.0 : 6.0) {
            Image(systemName: isInline ? "arrow.right" : "arrow.turn.down.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            content
        }
        .offset(y: isInline ? 0.0 : 1.0)
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
