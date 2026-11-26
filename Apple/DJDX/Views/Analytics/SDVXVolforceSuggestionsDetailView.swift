import SwiftUI

struct SDVXVolforceSuggestionRow: View {
    var namespace: Namespace.ID
    let suggestion: SDVXVolforceSuggestion

    var body: some View {
        SDVXScoreRow(namespace: namespace, record: suggestion.record) {
            AnalyticsSuggestionTarget {
                Text(verbatim: suggestion.targetGrade)
                    .fontWidth(.expanded)
                    .fontWeight(.black)
                    .sdvxGradeText()
                Divider().frame(maxHeight: 14.0)
                Text(verbatim: "VF")
                    .foregroundStyle(.secondary)
                    .fontWidth(.expanded)
                    .fontWeight(.bold)
                AnalyticsSuggestionGain(text: SDVXVolforce.gainText(suggestion.volforceGain))
            }
        }
    }
}

struct SDVXVolforceSuggestionsDetailView: View {
    @EnvironmentObject var navigationManager: NavigationManager

    let suggestions: [SDVXVolforceSuggestion]

    @Namespace private var namespace

    var body: some View {
        AnalyticsSuggestionList(items: suggestions) { suggestion in
            Button {
                navigationManager.push(SDVXScoresPath.scoreViewer(songRecord: suggestion.record))
            } label: {
                SDVXVolforceSuggestionRow(namespace: namespace, suggestion: suggestion)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }
}
