//
//  ScoreViewer.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import SwiftData
import SwiftUI

struct ScoreViewer: View {

    @Environment(\.modelContext) var modelContext

    @AppStorage(wrappedValue: false, "ScoresView.BeginnerLevelHidden") var isBeginnerLevelHidden: Bool

    @State var songRecord: IIDXSongRecord
    @State var songData: IIDXSong?

    var body: some View {
        List {
            if !isBeginnerLevelHidden,
               songRecord.beginnerScore.difficulty != 0 {
                ScoreSection(songTitle: songRecord.title, score: songRecord.beginnerScore,
                             noteCount: songData?.spNoteCount?.beginnerNoteCount)
            }
            if songRecord.normalScore.difficulty != 0 {
                ScoreSection(songTitle: songRecord.title, score: songRecord.normalScore,
                             noteCount: songData?.spNoteCount?.normalNoteCount)
            }
            if songRecord.hyperScore.difficulty != 0 {
                ScoreSection(songTitle: songRecord.title, score: songRecord.hyperScore,
                             noteCount: songData?.spNoteCount?.hyperNoteCount)
            }
            if songRecord.anotherScore.difficulty != 0 {
                ScoreSection(songTitle: songRecord.title, score: songRecord.anotherScore,
                             noteCount: songData?.spNoteCount?.anotherNoteCount)
            }
            if songRecord.leggendariaScore.difficulty != 0 {
                ScoreSection(songTitle: songRecord.title, score: songRecord.leggendariaScore,
                             noteCount: songData?.spNoteCount?.leggendariaNoteCount)
            }
        }
        .listSectionSpacing(.compact)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top, spacing: 0.0) {
            VStack(alignment: .center, spacing: 8.0) {
                VStack(alignment: .center, spacing: 2.0) {
                    Text(songRecord.genre)
                        .font(.caption2)
                        .fontWidth(.condensed)
                    Text(songRecord.title)
                        .bold()
                        .fontWidth(.condensed)
                    Text(songRecord.artist)
                        .font(.caption)
                        .fontWidth(.condensed)
                }
                Divider()
                IIDXLevelShowcase(songRecord: songRecord)
                Divider()
                HStack {
                    Text("""
Scores.Viewer.LastPlayDate.\(songRecord.lastPlayDate.formatted(date: .long, time: .shortened))
""")
                        .foregroundStyle(.tertiary)
                }
                .font(.caption2)
            }
            .padding([.bottom], 8.0)
            .padding([.leading, .trailing], 20.0)
            .frame(maxWidth: .infinity)
            .background(Material.bar)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .frame(height: 1/3)
                    .foregroundColor(.primary.opacity(0.2))
                    .ignoresSafeArea(edges: [.leading, .trailing])
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text(songRecord.version)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .bold()
                    .italic()
            }
        }
        .task {
            self.songData = (try? modelContext.fetch(
                FetchDescriptor<IIDXSong>(predicate: iidxSong(for: songRecord))
            ))?.first ?? nil
        }
    }
}
