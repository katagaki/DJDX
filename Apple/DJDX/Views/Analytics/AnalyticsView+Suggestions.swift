import SwiftUI

extension AnalyticsView {

    @ViewBuilder
    var suggestionsSection: some View {
        if model.sessionStore == nil {
            AnalyticsSuggestionsSection(
                cards: AnalyticsSuggestionCardID.iidxCards,
                columns: perLevelColumns,
                isEditing: isEditing,
                isExpanded: isSectionExpanded(.suggestions),
                onToggle: { toggleSection(.suggestions) },
                card: suggestionCard
            )
        }
    }

    @ViewBuilder
    func suggestionCard(_ cardID: AnalyticsSuggestionCardID) -> some View {
        switch cardID {
        case .iidxDJLevel: djLevelSuggestionsCard
        case .iidxClearLamp: clearLampSuggestionsCard
        case .iidxNotPlayedRecently: notPlayedRecentlySuggestionsCard
        default: EmptyView()
        }
    }

    var djLevelSuggestionsCard: some View {
        Button {
            navigationManager.push(AnalyticsPath.djLevelSuggestionsDetail)
        } label: {
            AnalyticsSuggestionCard(
                title: Text("Analytics.Suggestions.NextDJLevel"),
                systemImage: "crown",
                iconColor: .orange,
                items: model.djLevelSuggestions
            ) { suggestion in
                IIDXDJLevelSuggestionRow(namespace: analyticsNamespace, suggestion: suggestion)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .matchedTransitionSource(id: AnalyticsSuggestionCardID.iidxDJLevel.transitionID, in: analyticsNamespace)
    }

    var clearLampSuggestionsCard: some View {
        Button {
            navigationManager.push(AnalyticsPath.clearLampSuggestionsDetail)
        } label: {
            AnalyticsSuggestionCard(
                title: Text("Analytics.Suggestions.NextClearLamp.\(suggestionTargetClearType.rawValue)"),
                systemImage: "checkmark.seal",
                iconColor: IIDXClearType.color(for: suggestionTargetClearType.rawValue),
                items: model.clearLampSuggestions(for: suggestionTargetClearType)
            ) { suggestion in
                IIDXClearLampSuggestionRow(namespace: analyticsNamespace, suggestion: suggestion,
                                           targetClearType: suggestionTargetClearType)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .matchedTransitionSource(id: AnalyticsSuggestionCardID.iidxClearLamp.transitionID, in: analyticsNamespace)
    }

    var notPlayedRecentlySuggestionsCard: some View {
        Button {
            navigationManager.push(AnalyticsPath.notPlayedRecentlySuggestionsDetail)
        } label: {
            AnalyticsSuggestionCard(
                title: Text("Analytics.Suggestions.NotPlayedRecently"),
                systemImage: "clock.arrow.circlepath",
                iconColor: .teal,
                items: model.longUnplayedSuggestions
            ) { suggestion in
                IIDXUnplayedSuggestionRow(namespace: analyticsNamespace, suggestion: suggestion)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .matchedTransitionSource(id: AnalyticsSuggestionCardID.iidxNotPlayedRecently.transitionID,
                                 in: analyticsNamespace)
    }
}

// MARK: - Rows

struct IIDXDJLevelSuggestionRow: View {
    var namespace: Namespace.ID
    let suggestion: IIDXDJLevelSuggestion

    var body: some View {
        IIDXScoreRow(namespace: namespace, songRecord: suggestion.songRecord, level: suggestion.level,
                     score: suggestion.score, scoreRate: suggestion.scoreRate) {
            AnalyticsSuggestionTarget {
                IIDXMetallicText.djLevel(suggestion.targetDJLevel)
                AnalyticsSuggestionGain(text: "+\(suggestion.pointsNeeded)")
            }
        }
    }
}

struct IIDXClearLampSuggestionRow: View {
    var namespace: Namespace.ID
    let suggestion: IIDXChartSuggestion
    let targetClearType: IIDXClearType

    var body: some View {
        IIDXScoreRow(namespace: namespace, songRecord: suggestion.songRecord, level: suggestion.level,
                     score: suggestion.score, scoreRate: suggestion.scoreRate) {
            AnalyticsSuggestionTarget {
                IIDXMetallicText.clearType(targetClearType.rawValue)
            }
        }
    }
}

struct IIDXUnplayedSuggestionRow: View {
    var namespace: Namespace.ID
    let suggestion: IIDXChartSuggestion

    var body: some View {
        IIDXScoreRow(namespace: namespace, songRecord: suggestion.songRecord, level: suggestion.level,
                     score: suggestion.score, scoreRate: suggestion.scoreRate) {
            HStack(spacing: 4.0) {
                Image(systemName: "clock")
                    .font(.caption2.weight(.bold))
                Text(suggestion.songRecord.lastPlayDate, format: .relative(presentation: .named))
                    .fontWidth(.condensed)
            }
            .foregroundStyle(.secondary)
            .offset(y: 1.0)
        }
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
                    .navigationTransition(.zoom(sourceID: "\(songRecord.title).\(level.rawValue)", in: namespace))
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

    @AppStorage(wrappedValue: IIDXClearType.hardClear, "Analytics.Suggestions.TargetClearType")
    var targetClearType: IIDXClearType

    var body: some View {
        IIDXSuggestionsDetailView(
            items: model.clearLampSuggestions(for: targetClearType),
            songRecord: \.songRecord,
            level: \.level
        ) { suggestion, namespace in
            IIDXClearLampSuggestionRow(namespace: namespace, suggestion: suggestion,
                                       targetClearType: targetClearType)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section("Analytics.Suggestions.TargetClearType") {
                        Picker("Analytics.Suggestions.TargetClearType",
                               selection: $targetClearType.animation(.smooth.speed(2.0))) {
                            ForEach(AnalyticsModel.suggestionTargetClearTypes, id: \.self) { clearType in
                                Text(verbatim: clearType.rawValue)
                                    .tag(clearType)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                } label: {
                    Label("Analytics.Suggestions.Settings", systemImage: "gearshape")
                }
            }
        }
    }
}
