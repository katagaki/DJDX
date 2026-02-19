//
//  NewHighScoresDetailView.swift
//  DJDX
//
//  Created on 2026/02/17.
//

import SwiftUI

struct NewHighScoresDetailView: View {
    @Binding var newHighScores: [NewHighScoreEntry]

    var body: some View {
        List {
            if newHighScores.isEmpty {
                Text("Analytics.NoData")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(newHighScores) { entry in
                    HStack(alignment: .center, spacing: 8.0) {
                        VStack(alignment: .leading, spacing: 2.0) {
                            Text(entry.songTitle)
                                .bold()
                                .fontWidth(.condensed)
                            Text(entry.songArtist)
                                .font(.caption)
                                .fontWidth(.condensed)
                            HStack(spacing: 4.0) {
                                Text("\(entry.previousScore)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .strikethrough()
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(entry.newScore)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                                Text("Analytics.NewHighScore.\(entry.newScore - entry.previousScore)")
                                    .font(.caption2)
                                    .foregroundStyle(.orange.opacity(0.8))
                            }
                            if entry.newDJLevel != entry.previousDJLevel {
                                HStack(spacing: 4.0) {
                                    Text(entry.previousDJLevel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .strikethrough()
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(entry.newDJLevel)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        Spacer(minLength: 0.0)
                        IIDXLevelLabel(
                            levelType: entry.level,
                            score: IIDXLevelScore(
                                level: entry.level,
                                difficulty: entry.difficulty,
                                score: entry.newScore,
                                perfectGreatCount: 0,
                                greatCount: 0,
                                missCount: 0,
                                clearType: "",
                                djLevel: entry.newDJLevel
                            )
                        )
                        .padding([.top, .bottom], 6.0)
                        .frame(width: 78.0, alignment: .center)
                        .background(.thinMaterial)
                        .clipShape(.rect(cornerRadius: 6.0))
                    }
                    .padding(.vertical, 2.0)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Analytics.NewHighScores")
        .navigationBarTitleDisplayMode(.inline)
    }
}
