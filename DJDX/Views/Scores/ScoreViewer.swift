//
//  ScoreViewer.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import SwiftUI

struct ScoreViewer: View {
    var songRecord: EPOLISSongRecord

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
        .safeAreaInset(edge: .top) {
            VStack(alignment: .center, spacing: 8.0) {
                VStack(alignment: .center, spacing: 2.0) {
                    DetailedSongTitle(songRecord: songRecord,
                                      isGenreVisible: .constant(true))
                }
                Divider()
                LevelShowcase(songRecord: songRecord)
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

#Preview {
    ScoreViewer(songRecord: EPOLISSongRecord(csvRowData: [
        "バージョン": "CastHour",
        "タイトル": "禊",
        "ジャンル": "HARD PSY TRANCE",
        "アーティスト": "Nhato",
        "プレー回数": "12",
        "BEGINNER 難易度": "0",
        "BEGINNER スコア": "0",
        "BEGINNER PGreat": "0",
        "BEGINNER Great": "0",
        "BEGINNER ミスカウント": "---",
        "BEGINNER クリアタイプ": "NO PLAY",
        "BEGINNER DJ LEVEL": "---",
        "NORMAL 難易度": "6",
        "NORMAL スコア": "0",
        "NORMAL PGreat": "0",
        "NORMAL Great": "0",
        "NORMAL ミスカウント": "---",
        "NORMAL クリアタイプ": "CLEAR",
        "NORMAL DJ LEVEL": "---",
        "HYPER 難易度": "10",
        "HYPER スコア": "1460",
        "HYPER PGreat": "560",
        "HYPER Great": "340",
        "HYPER ミスカウント": "45",
        "HYPER クリアタイプ": "CLEAR",
        "HYPER DJ LEVEL": "B",
        "ANOTHER 難易度": "12",
        "ANOTHER スコア": "0",
        "ANOTHER PGreat": "0",
        "ANOTHER Great": "0",
        "ANOTHER ミスカウント": "---",
        "ANOTHER クリアタイプ": "NO PLAY",
        "ANOTHER DJ LEVEL": "---",
        "LEGGENDARIA 難易度": "0",
        "LEGGENDARIA スコア": "0",
        "LEGGENDARIA PGreat": "0",
        "LEGGENDARIA Great": "0",
        "LEGGENDARIA ミスカウント": "---",
        "LEGGENDARIA クリアタイプ": "NO PLAY",
        "LEGGENDARIA DJ LEVEL": "---",
        "最終プレー日時": "2024-05-01 19:39"
    ]))
}
