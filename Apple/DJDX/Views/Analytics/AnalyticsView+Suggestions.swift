import SwiftUI

struct IIDXSuggestionsSection: View {
    @EnvironmentObject var navigationManager: NavigationManager

    @Bindable var model: AnalyticsModel
    @Binding var isEditing: Bool
    var analyticsNamespace: Namespace.ID

    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var playTypeToShow: IIDXPlayType
    @AppStorage(wrappedValue: IIDXVersion.zinrai, "Global.IIDX.Version") var iidxVersion: IIDXVersion
    @State var shareCardID: AnalyticsSuggestionCardID?

    var rowLimit: Int {
        isEditing ? AnalyticsSuggestionCardID.editingPreviewLimit : AnalyticsSuggestionCardID.sectionLimit
    }

    var body: some View {
        if model.sessionStore == nil {
            AnalyticsSuggestionsSection(
                cards: AnalyticsSuggestionCardID.iidxCards,
                isEditing: isEditing,
                title: sectionTitle,
                canShare: canShare,
                onShare: { shareCardID = $0 },
                content: suggestionRows
            )
            .sheet(item: $shareCardID) { cardID in
                ShareCardComposer(
                    game: Game.stored,
                    profile: Game.stored == .iidxArcade ? .iidx(playType: playTypeToShow) : ShareCardProfile(),
                    entries: shareEntries(for: cardID),
                    playStyle: playTypeToShow.displayName()
                )
            }
        }
    }

    func canShare(_ cardID: AnalyticsSuggestionCardID) -> Bool {
        if let target = cardID.targetClearType {
            return !model.clearLampSuggestions(for: target).isEmpty
        }
        switch cardID {
        case .iidxDJLevel: return !model.djLevelSuggestions.isEmpty
        case .iidxNotPlayedRecently: return !model.longUnplayedSuggestions.isEmpty
        default: return false
        }
    }

    func shareEntries(for cardID: AnalyticsSuggestionCardID) -> [ShareCardEntry] {
        let limit = AnalyticsSuggestionCardID.sectionLimit
        if let target = cardID.targetClearType {
            return model.clearLampSuggestions(for: target).prefix(limit).map {
                ShareCardEntry(iidxSongRecord: $0.songRecord, level: $0.level,
                               score: $0.score, scoreRate: $0.scoreRate, iidxVersion: iidxVersion)
            }
        }
        switch cardID {
        case .iidxDJLevel:
            return model.djLevelSuggestions.prefix(limit).map {
                ShareCardEntry(iidxSongRecord: $0.songRecord, level: $0.level,
                               score: $0.score, scoreRate: $0.scoreRate, iidxVersion: iidxVersion)
            }
        case .iidxNotPlayedRecently:
            return model.longUnplayedSuggestions.prefix(limit).map {
                ShareCardEntry(iidxSongRecord: $0.songRecord, level: $0.level,
                               score: $0.score, scoreRate: $0.scoreRate, iidxVersion: iidxVersion)
            }
        default:
            return []
        }
    }

    func sectionTitle(for cardID: AnalyticsSuggestionCardID) -> LocalizedStringKey {
        if let target = cardID.targetClearType {
            return "Analytics.Suggestions.NextClearLamp.\(target.rawValue)"
        }
        switch cardID {
        case .iidxDJLevel: return "Analytics.Suggestions.NextDJLevel"
        case .iidxNotPlayedRecently: return "Analytics.Suggestions.NotPlayedRecently"
        default: return ""
        }
    }

    @ViewBuilder
    func suggestionRows(_ cardID: AnalyticsSuggestionCardID) -> some View {
        if let target = cardID.targetClearType {
            AnalyticsSuggestionPreviewRows(items: model.clearLampSuggestions(for: target), limit: rowLimit) { suggestion in
                navigationManager.push(
                    ScoresPath.scoreViewer(songRecord: suggestion.songRecord, initialLevel: suggestion.level)
                )
            } row: { suggestion in
                IIDXClearLampSuggestionRow(namespace: analyticsNamespace, suggestion: suggestion,
                                           targetClearType: target)
            }
        } else {
            switch cardID {
            case .iidxDJLevel:
                AnalyticsSuggestionPreviewRows(items: model.djLevelSuggestions, limit: rowLimit) { suggestion in
                    navigationManager.push(
                        ScoresPath.scoreViewer(songRecord: suggestion.songRecord, initialLevel: suggestion.level)
                    )
                } row: { suggestion in
                    IIDXDJLevelSuggestionRow(namespace: analyticsNamespace, suggestion: suggestion)
                }
            case .iidxNotPlayedRecently:
                AnalyticsSuggestionPreviewRows(items: model.longUnplayedSuggestions, limit: rowLimit) { suggestion in
                    navigationManager.push(
                        ScoresPath.scoreViewer(songRecord: suggestion.songRecord, initialLevel: suggestion.level)
                    )
                } row: { suggestion in
                    IIDXUnplayedSuggestionRow(namespace: analyticsNamespace, suggestion: suggestion)
                }
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Rows

struct IIDXDJLevelSuggestionRow: View {
    var namespace: Namespace.ID
    let suggestion: IIDXDJLevelSuggestion

    var body: some View {
        var row = IIDXScoreRow(namespace: namespace, songRecord: suggestion.songRecord, level: suggestion.level,
                               score: suggestion.score, scoreRate: suggestion.scoreRate) {
            AnalyticsSuggestionTarget(isInline: true) {
                IIDXMetallicText.djLevel(suggestion.targetDJLevel)
                AnalyticsSuggestionGain(text: "+\(suggestion.pointsNeeded)")
            }
        }
        row.showsGenre = false
        row.showsScore = false
        row.showsLastPlayDate = false
        row.isAccessoryInline = true
        row.verticalPadding = 5.0
        return row
    }
}

struct IIDXClearLampSuggestionRow: View {
    var namespace: Namespace.ID
    let suggestion: IIDXChartSuggestion
    let targetClearType: IIDXClearType

    var body: some View {
        var row = IIDXScoreRow(namespace: namespace, songRecord: suggestion.songRecord, level: suggestion.level,
                               score: suggestion.score, scoreRate: suggestion.scoreRate) {
        }
        row.showsGenre = false
        row.showsMetadata = false
        row.verticalPadding = 5.0
        return row
    }
}

struct IIDXUnplayedSuggestionRow: View {
    var namespace: Namespace.ID
    let suggestion: IIDXChartSuggestion

    var body: some View {
        var row = IIDXScoreRow(namespace: namespace, songRecord: suggestion.songRecord, level: suggestion.level,
                               score: suggestion.score, scoreRate: suggestion.scoreRate)
        row.showsGenre = false
        row.showsScore = false
        row.showsLastPlayDate = false
        row.verticalPadding = 5.0
        return row
    }
}

// MARK: - Detail views

struct IIDXSuggestionsDetailView<Item: Identifiable, Row: View>: View {
    let items: [Item]
    let songRecord: (Item) -> IIDXSongRecord
    let level: (Item) -> IIDXLevel
    @ViewBuilder let row: (Item, Namespace.ID) -> Row

    @Namespace private var namespace

    @State private var songCompactTitles: [String: IIDXSong] = [:]

    private let fetcher = IIDXReader()

    var body: some View {
        AnalyticsSuggestionList(items: items) { item in
            let songRecord = songRecord(item)
            let level = level(item)
            NavigationLink {
                IIDXScoreViewer(songRecord: songRecord, noteCount: noteCount, initialLevel: level)
            } label: {
                row(item, namespace)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .task {
            songCompactTitles = await fetcher.songCompactTitles()
        }
    }

    private func noteCount(_ songRecord: IIDXSongRecord, _ level: IIDXLevel) -> Int? {
        let keyPath: KeyPath<IIDXNoteCount, Int?>?
        switch level {
        case .beginner: keyPath = \.beginnerNoteCount
        case .normal: keyPath = \.normalNoteCount
        case .hyper: keyPath = \.hyperNoteCount
        case .another: keyPath = \.anotherNoteCount
        case .leggendaria: keyPath = \.leggendariaNoteCount
        default: keyPath = nil
        }
        guard let keyPath, let song = songCompactTitles[songRecord.titleCompact()] else { return nil }
        return song.spNoteCount?[keyPath: keyPath]
    }
}

struct IIDXDJLevelSuggestionsDetailView: View {
    let suggestions: [IIDXDJLevelSuggestion]

    var body: some View {
        IIDXSuggestionsDetailView(items: suggestions,
                                  songRecord: \.songRecord,
                                  level: \.level) { suggestion, namespace in
            IIDXDJLevelSuggestionRow(namespace: namespace, suggestion: suggestion)
        }
    }
}

struct IIDXUnplayedSuggestionsDetailView: View {
    let suggestions: [IIDXChartSuggestion]

    var body: some View {
        IIDXSuggestionsDetailView(items: suggestions,
                                  songRecord: \.songRecord,
                                  level: \.level) { suggestion, namespace in
            IIDXUnplayedSuggestionRow(namespace: namespace, suggestion: suggestion)
        }
    }
}

struct IIDXClearLampSuggestionsDetailView: View {
    @Bindable var model: AnalyticsModel
    let targetClearType: IIDXClearType

    var body: some View {
        IIDXSuggestionsDetailView(
            items: model.clearLampSuggestions(for: targetClearType),
            songRecord: \.songRecord,
            level: \.level
        ) { suggestion, namespace in
            IIDXClearLampSuggestionRow(namespace: namespace, suggestion: suggestion,
                                       targetClearType: targetClearType)
        }
    }
}
