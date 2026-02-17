//
//  NewHighScoresCard.swift
//  DJDX
//
//  Created on 2026/02/17.
//

import SwiftUI

struct NewHighScoresCard: View {
    @Binding var newHighScores: [NewHighScoreEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 4.0) {
            if newHighScores.isEmpty {
                Text("Analytics.NoData")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60.0)
            } else {
                Text("\(newHighScores.count)")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                Text("Analytics.NewHighScores.Subtitle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct NewHighScoreEntry: Identifiable, Hashable {
    let id = UUID()
    let songTitle: String
    let level: IIDXLevel
    let difficulty: Int
    let newScore: Int
    let previousScore: Int
    let newDJLevel: String
    let previousDJLevel: String
}
