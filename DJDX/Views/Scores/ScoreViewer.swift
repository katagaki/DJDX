//
//  ScoreViewer.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import SwiftData
import SwiftUI

struct ScoreViewer: View {

    @EnvironmentObject var playData: PlayDataManager

    @AppStorage(wrappedValue: false, "ScoresView.BeginnerLevelHidden") var isBeginnerLevelHidden: Bool

    var songRecord: IIDXSongRecord

    var body: some View {
        List {
            if !isBeginnerLevelHidden, songRecord.beginnerScore.difficulty != 0 {
                ScoreSection(songTitle: songRecord.title, score: songRecord.beginnerScore,
                             noteCount: playData.noteCount(for: songRecord, of: .beginner))
            }
            if songRecord.normalScore.difficulty != 0 {
                ScoreSection(songTitle: songRecord.title, score: songRecord.normalScore,
                             noteCount: playData.noteCount(for: songRecord, of: .normal))
            }
            if songRecord.hyperScore.difficulty != 0 {
                ScoreSection(songTitle: songRecord.title, score: songRecord.hyperScore,
                             noteCount: playData.noteCount(for: songRecord, of: .hyper))
            }
            if songRecord.anotherScore.difficulty != 0 {
                ScoreSection(songTitle: songRecord.title, score: songRecord.anotherScore,
                             noteCount: playData.noteCount(for: songRecord, of: .another))
            }
            if songRecord.leggendariaScore.difficulty != 0 {
                ScoreSection(songTitle: songRecord.title, score: songRecord.leggendariaScore,
                             noteCount: playData.noteCount(for: songRecord, of: .leggendaria))
            }
        }
        .listSectionSpacing(.compact)
        .navigationTitle("ViewTitle.Scores.Song")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Spacer()
            }
        }
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
    }
}
