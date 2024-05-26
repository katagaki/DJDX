//
//  DetailedSongTitle.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import SwiftUI

struct DetailedSongTitle: View {
    var songRecord: IIDXSongRecord
    @State var score: Int?
    @Binding var isArtistVisible: Bool
    @Binding var isGenreVisible: Bool
    @Binding var isScoreVisible: Bool
    @Binding var isLastPlayDateVisible: Bool

    var body: some View {
        if isGenreVisible {
            Text(songRecord.genre)
                .font(.caption2)
                .fontWidth(.condensed)
        }
        Text(songRecord.title)
            .bold()
            .fontWidth(.condensed)
        if isArtistVisible {
            Text(songRecord.artist)
                .font(.caption)
                .fontWidth(.condensed)
        }
        if isScoreVisible || isLastPlayDateVisible {
            HStack {
                if isScoreVisible, let score {
                    Text(String(score))
                        .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                        .font(.caption)
                        .fontWeight(.heavy)
                }
                if isScoreVisible && score != nil && isLastPlayDateVisible {
                    Divider()
                        .frame(maxHeight: 14.0)
                }
                if isLastPlayDateVisible {
                    Text(RelativeDateTimeFormatter().localizedString(for: songRecord.lastPlayDate, relativeTo: .now))
                        .font(.caption2)
                        .fontWidth(.condensed)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
