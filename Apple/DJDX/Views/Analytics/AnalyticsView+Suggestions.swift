import SwiftUI

extension AnalyticsView {

    @ViewBuilder
    var suggestionsSection: some View {
        if !isEditing && model.sessionStore == nil {
            VStack(spacing: 12.0) {
                AnalyticsSectionHeader(
                    title: AnalyticsSection.suggestions.titleKey,
                    isCollapsible: true,
                    isExpanded: isSectionExpanded(.suggestions)
                ) {
                    toggleSection(.suggestions)
                }
                if isSectionExpanded(.suggestions) {
                    LazyVGrid(columns: perLevelColumns, spacing: 12.0) {
                        djLevelSuggestionsCard
                        clearLampSuggestionsCard
                    }
                    .padding(.horizontal)
                }
            }
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
                count: model.djLevelSuggestions.count,
                previews: model.djLevelSuggestions.prefix(3).map { suggestion in
                    AnalyticsSuggestionPreview(
                        id: suggestion.id,
                        title: suggestion.songTitle,
                        detail: "\(suggestion.level.chartName) \(suggestion.difficulty) · \(suggestion.targetDJLevel)",
                        value: "+\(suggestion.pointsNeeded)"
                    )
                }
            )
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "Suggestions.DJLevel", in: analyticsNamespace)
    }

    var clearLampSuggestionsCard: some View {
        let suggestions = model.clearLampSuggestions(for: suggestionTargetClearType)
        return Button {
            navigationManager.push(AnalyticsPath.clearLampSuggestionsDetail)
        } label: {
            AnalyticsSuggestionCard(
                title: Text("Analytics.Suggestions.NextClearLamp.\(suggestionTargetClearType.rawValue)"),
                systemImage: "checkmark.seal",
                iconColor: IIDXClearType.color(for: suggestionTargetClearType.rawValue),
                count: suggestions.count,
                previews: suggestions.prefix(3).map { suggestion in
                    AnalyticsSuggestionPreview(
                        id: suggestion.id,
                        title: suggestion.songTitle,
                        detail: "\(suggestion.level.chartName) · \(suggestion.clearType)",
                        value: "LEVEL \(suggestion.difficulty)"
                    )
                }
            )
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "Suggestions.ClearLamp", in: analyticsNamespace)
    }
}

struct IIDXDJLevelSuggestionsDetailView: View {
    let suggestions: [IIDXDJLevelSuggestion]

    var body: some View {
        List {
            if suggestions.isEmpty {
                Text("Analytics.Suggestions.Empty")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(suggestions) { suggestion in
                    AnalyticsSuggestionRow(
                        title: suggestion.songTitle,
                        current: suggestion.currentDJLevel,
                        target: suggestion.targetDJLevel,
                        detail: "EX SCORE \(suggestion.score) → \(suggestion.targetScore)",
                        gain: "+\(suggestion.pointsNeeded)",
                        difficulty: suggestion.level.chartName,
                        difficultyColor: suggestion.level.chartColor,
                        level: String(suggestion.difficulty)
                    )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

struct IIDXClearLampSuggestionsDetailView: View {
    @Bindable var model: AnalyticsModel

    @AppStorage(wrappedValue: IIDXClearType.hardClear, "Analytics.Suggestions.TargetClearType")
    var targetClearType: IIDXClearType

    var body: some View {
        let suggestions = model.clearLampSuggestions(for: targetClearType)
        List {
            Section {
                Picker("Analytics.Suggestions.TargetClearType", selection: $targetClearType) {
                    ForEach(AnalyticsModel.suggestionTargetClearTypes, id: \.self) { clearType in
                        Text(verbatim: clearType.rawValue)
                            .tag(clearType)
                    }
                }
                .pickerStyle(.menu)
                .listRowBackground(Color.clear)
            }
            Section {
                if suggestions.isEmpty {
                    Text("Analytics.Suggestions.Empty")
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(suggestions) { suggestion in
                        AnalyticsSuggestionRow(
                            title: suggestion.songTitle,
                            current: suggestion.clearType,
                            target: targetClearType.rawValue,
                            detail: "EX SCORE \(suggestion.score)",
                            gain: "",
                            difficulty: suggestion.level.chartName,
                            difficultyColor: suggestion.level.chartColor,
                            level: String(suggestion.difficulty)
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
