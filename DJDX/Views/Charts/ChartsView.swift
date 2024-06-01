//
//  ChartsView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/01.
//

import Komponents
import SwiftData
import SwiftUI

struct ChartsView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navigationManager: NavigationManager

    @State var allSongs: [IIDXSong] = []

    var body: some View {
        NavigationStack(path: $navigationManager[.charts]) {
            List {
                ForEach(allSongs) { song in
                    NavigationLink(song.title) {
                        List {
                            Section {
                                VStack(alignment: .leading, spacing: 8.0) {
                                    DetailRow("TIME", value: song.time, style: Color.accentColor)
                                    DetailRow("MOVIE", value: song.movie, style: Color.accentColor)
                                    DetailRow("LAYER", value: song.layer, style: Color.accentColor)
                                }
                            }
                            if let noteCount = song.spNoteCount {
                                Section {
                                    VStack(alignment: .leading, spacing: 8.0) {
                                        LevelDetailRow(level: .beginner, value: noteCount.beginnerNoteCount)
                                        LevelDetailRow(level: .normal, value: noteCount.normalNoteCount)
                                        LevelDetailRow(level: .hyper, value: noteCount.hyperNoteCount)
                                        LevelDetailRow(level: .another, value: noteCount.anotherNoteCount)
                                        LevelDetailRow(level: .leggendaria, value: noteCount.leggendariaNoteCount)
                                    }
                                } header: {
                                    ListSectionHeader(text: "SP")
                                        .font(.body)
                                        .fontWidth(.expanded)
                                        .fontWeight(.black)
                                }
                            }
                            if let noteCount = song.dpNoteCount {
                                Section {
                                    VStack(alignment: .leading, spacing: 8.0) {
                                        LevelDetailRow(level: .normal, value: noteCount.normalNoteCount)
                                        LevelDetailRow(level: .hyper, value: noteCount.hyperNoteCount)
                                        LevelDetailRow(level: .another, value: noteCount.anotherNoteCount)
                                        LevelDetailRow(level: .leggendaria, value: noteCount.leggendariaNoteCount)
                                    }
                                } header: {
                                    ListSectionHeader(text: "DP")
                                        .font(.body)
                                        .fontWidth(.expanded)
                                        .fontWeight(.black)
                                }
                            }
                        }
                        .navigationTitle(song.title)
                        .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("ViewTitle.Charts")
            .task {
                reloadAllSongs()
            }
            .refreshable {
                reloadAllSongs()
            }
        }
    }

    func reloadAllSongs() {
        withAnimation(.snappy.speed(2.0)) {
            allSongs.removeAll()
            allSongs.append(contentsOf: (try? modelContext.fetch(
                FetchDescriptor<IIDXSong>(
                    sortBy: [SortDescriptor(\.title, order: .forward)]
                )
            )) ?? [])
        }
    }
}
