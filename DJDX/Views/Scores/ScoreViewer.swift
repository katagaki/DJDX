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

    var songRecord: IIDXSongRecord
    @State var songData: IIDXSong?

    var body: some View {
        List {
            if songRecord.beginnerScore.difficulty != 0 {
                ScoreSection(levelScore: songRecord.beginnerScore)
            }
            if songRecord.normalScore.difficulty != 0 {
                ScoreSection(levelScore: songRecord.normalScore)
            }
            if songRecord.hyperScore.difficulty != 0 {
                ScoreSection(levelScore: songRecord.hyperScore)
            }
            if songRecord.anotherScore.difficulty != 0 {
                ScoreSection(levelScore: songRecord.anotherScore)
            }
            if songRecord.leggendariaScore.difficulty != 0 {
                ScoreSection(levelScore: songRecord.leggendariaScore)
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
                    Text("最終プレー日時：\(songRecord.lastPlayDate.formatted(date: .long, time: .shortened))")
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
