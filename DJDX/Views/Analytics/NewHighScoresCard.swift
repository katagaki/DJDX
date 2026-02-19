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
            Spacer(minLength: 0)
            if newHighScores.isEmpty {
                Text("Analytics.NoData")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(newHighScores.count)")
                    .font(.system(size: 40.0, weight: .black))
                    .fontWidth(.expanded)
                    .foregroundStyle(.primary)
            }
        }
    }
}

struct NewHighScoreEntry: Identifiable, Hashable {
    let id = UUID()
    let songTitle: String
    let songArtist: String
    let level: IIDXLevel
    let difficulty: Int
    let newScore: Int
    let previousScore: Int
    let newDJLevel: String
    let previousDJLevel: String
}
