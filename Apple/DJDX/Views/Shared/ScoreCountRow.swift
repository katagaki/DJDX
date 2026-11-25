import SwiftUI

struct ScoreCountRow: View {
    let count: Int

    var body: some View {
        HStack {
            Text("Scores.ChartCount.\(count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8.0)
    }
}
