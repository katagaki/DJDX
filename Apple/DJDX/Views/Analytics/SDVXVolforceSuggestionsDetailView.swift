import SwiftUI

struct SDVXVolforceSuggestionRow: View {
    var namespace: Namespace.ID
    let suggestion: SDVXVolforceSuggestion

    var body: some View {
        var row = SDVXScoreRow(namespace: namespace, record: suggestion.record) {
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
        row.verticalPadding = 5.0
        return row
    }
}
