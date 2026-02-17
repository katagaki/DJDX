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
                    VStack(alignment: .leading, spacing: 4.0) {
                        Text(entry.songTitle)
                            .font(.body.weight(.medium))
                        HStack(spacing: 4.0) {
                            Text(entry.level.code())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text("LV.\(entry.difficulty)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
                            Text("(+\(entry.newScore - entry.previousScore))")
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
                    .padding(.vertical, 2.0)
                }
            }
        }
        .navigationTitle("Analytics.NewHighScores")
        .navigationBarTitleDisplayMode(.inline)
    }
}
