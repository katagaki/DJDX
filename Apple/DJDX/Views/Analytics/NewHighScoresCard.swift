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
                Text(verbatim: "0")
                    .font(.system(size: 20.0, weight: .black))
                    .fontWidth(.expanded)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(newHighScores.count)")
                    .font(.system(size: 20.0, weight: .black))
                    .fontWidth(.expanded)
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NewHighScoreEntry: Identifiable, Hashable, IIDXNewEntry {
    let id = UUID()
    let songRecord: IIDXSongRecord
    let level: IIDXLevel
    let score: IIDXLevelScore
    let previousScore: Int
}
