//
//  ChartsView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/01.
//

import SwiftData
import SwiftUI

struct ChartsView: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @Query(sort: \IIDXSong.title) var songs: [IIDXSong]

    var body: some View {
        NavigationStack(path: $navigationManager[.charts]) {
            List {
                ForEach(songs) { song in
                    NavigationLink(song.title) {
                        List {
                            Text(song.time)
                            Text(song.movie)
                            Text(song.layer)
                        }
                            .navigationTitle(song.title)
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("ViewTitle.Charts")
        }
    }
}

#Preview {
    ChartsView()
}
