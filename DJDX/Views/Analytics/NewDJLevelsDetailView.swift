//
//  NewDJLevelsDetailView.swift
//  DJDX
//
//  Created on 2026/03/12.
//

import SwiftUI

struct NewDJLevelsDetailView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @Binding var newDJLevels: [NewDJLevelEntry]
    var title: String

    var body: some View {
        List {
            if newDJLevels.isEmpty {
                Text("Analytics.NoData")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(newDJLevels) { entry in
                    HStack(alignment: .center, spacing: 8.0) {
                        VStack(alignment: .leading, spacing: 2.0) {
                            Text(entry.songTitle)
                                .bold()
                                .fontWidth(.condensed)
                            Text(entry.songArtist)
                                .font(.caption)
                                .fontWidth(.condensed)
                            HStack(spacing: 4.0) {
                                Group {
                                    Text(entry.previousDJLevel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .strikethrough()
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(entry.djLevel)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(
                                            IIDXDJLevel.style(for: entry.djLevel, colorScheme: colorScheme)
                                        )
                                }
                                .fontWeight(.black)
                                .fontWidth(.expanded)
                            }
                        }
                        Spacer(minLength: 0.0)
                        IIDXLevelLabel(
                            levelType: entry.level,
                            score: IIDXLevelScore(
                                level: entry.level,
                                difficulty: entry.difficulty,
                                djLevel: entry.djLevel
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
