//
//  DetailedSongTitle.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import SwiftUI

struct DetailedSongTitle: View {
    var songRecord: EPOLISSongRecord
    @Binding var isGenreVisible: Bool

    var body: some View {
        if isGenreVisible {
            Text(songRecord.genre)
                .font(.caption2)
                .fontWidth(.condensed)
                .foregroundStyle(.secondary)
        }
        Text(songRecord.title)
            .bold()
            .fontWidth(.condensed)
        Text(songRecord.artist)
            .font(.caption2)
            .fontWidth(.condensed)
    }
}
