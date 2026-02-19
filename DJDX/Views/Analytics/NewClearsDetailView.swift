//
//  NewClearsDetailView.swift
//  DJDX
//
//  Created on 2026/02/17.
//

import SwiftUI

struct NewClearsDetailView: View {
    @Binding var newClears: [NewClearEntry]
    var title: String

    var body: some View {
        List {
            if newClears.isEmpty {
                Text("Analytics.NoData")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(newClears) { entry in
                    HStack(alignment: .center, spacing: 8.0) {
                        VStack(alignment: .leading, spacing: 2.0) {
                            Text(entry.songTitle)
                                .bold()
                                .fontWidth(.condensed)
                            Text(entry.songArtist)
                                .font(.caption)
                                .fontWidth(.condensed)
                            HStack(spacing: 4.0) {
                                Text(entry.previousClearType)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .strikethrough()
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(entry.clearType)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        }
                        Spacer(minLength: 0.0)
                        IIDXLevelLabel(
                            levelType: entry.level,
                            score: IIDXLevelScore(
                                level: entry.level,
                                difficulty: entry.difficulty,
                                score: 0,
                                perfectGreatCount: 0,
                                greatCount: 0,
                                missCount: 0,
                                clearType: entry.clearType,
                                djLevel: "---"
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
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
