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
                                Text(song.time)
                                Text(song.movie)
                                Text(song.layer)
                            }
                            if let noteCount = song.spNoteCount {
                                Section {
                                    Text(String(noteCount.beginnerNoteCount ?? 0))
                                    Text(String(noteCount.normalNoteCount ?? 0))
                                    Text(String(noteCount.hyperNoteCount ?? 0))
                                    Text(String(noteCount.anotherNoteCount ?? 0))
                                    Text(String(noteCount.leggendariaNoteCount ?? 0))
                                } header: {
                                    ListSectionHeader(text: "SP")
                                        .font(.body)
                                }
                            }
                            if let noteCount = song.dpNoteCount {
                                Section {
                                    Text(String(noteCount.normalNoteCount ?? 0))
                                    Text(String(noteCount.hyperNoteCount ?? 0))
                                    Text(String(noteCount.anotherNoteCount ?? 0))
                                    Text(String(noteCount.leggendariaNoteCount ?? 0))
                                } header: {
                                    ListSectionHeader(text: "DP")
                                        .font(.body)
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
