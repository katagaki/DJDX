//
//  ScoreRow.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/02.
//

import SwiftUI

struct ScoreRow: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @AppStorage(wrappedValue: false, "ScoresView.ArtistVisible") var isArtistVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.LevelVisible") var isLevelVisible: Bool
    @AppStorage(wrappedValue: false, "ScorewView.GenreVisible") var isGenreVisible: Bool
    @AppStorage(wrappedValue: true, "ScorewView.DJLevelVisible") var isDJLevelVisible: Bool
    @AppStorage(wrappedValue: true, "ScorewView.ScoreVisible") var isScoreVisible: Bool
    @AppStorage(wrappedValue: false, "ScorewView.LastPlayDateVisible") var isLastPlayDateVisible: Bool

    @State var songRecord: IIDXSongRecord
    @Binding var levelToShow: IIDXLevel

    var body: some View {
        VStack(alignment: .trailing, spacing: 4.0) {
            HStack(alignment: .center, spacing: 8.0) {
                VStack(alignment: .leading, spacing: 2.0) {
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
                    if isDJLevelVisible || isScoreVisible || isLastPlayDateVisible {
                        HStack {
                            if let score = songRecord.score(for: levelToShow), score.score != 0 {
                                Group {
                                    if isDJLevelVisible {
                                        Group {
                                            switch colorScheme {
                                            case .light:
                                                Text(score.djLevel)
                                                    .foregroundStyle(
                                                        LinearGradient(colors: [.cyan, .blue],
                                                                       startPoint: .top,
                                                                       endPoint: .bottom)
                                                    )
                                            case .dark:
                                                Text(score.djLevel)
                                                    .foregroundStyle(
                                                        LinearGradient(colors: [.white, .cyan],
                                                                       startPoint: .top,
                                                                       endPoint: .bottom)
                                                    )
                                            @unknown default:
                                                Text(score.djLevel)
                                            }
                                        }
                                        .fontWidth(.expanded)
                                        .fontWeight(.black)
                                    }
                                    if isScoreVisible {
                                        if isDJLevelVisible {
                                            Divider()
                                                .frame(maxHeight: 14.0)
                                        }
                                        Text(String(score.score))
                                            .foregroundStyle(LinearGradient(colors: [.cyan, .blue],
                                                                            startPoint: .top,
                                                                            endPoint: .bottom))
                                            .fontWeight(.heavy)
                                    }
                                }
                                .font(.caption)
                                if isLastPlayDateVisible {
                                    if isScoreVisible {
                                        Divider()
                                            .frame(maxHeight: 14.0)
                                    }
                                    Text(RelativeDateTimeFormatter().localizedString(
                                        for: songRecord.lastPlayDate,
                                        relativeTo: .now
                                    ))
                                    .font(.caption2)
                                    .fontWidth(.condensed)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Spacer(minLength: 0.0)
                if isLevelVisible, levelToShow != .all {
                    IIDXLevelLabel(levelType: levelToShow, songRecord: songRecord)
                }
            }
            if isLevelVisible, levelToShow == .all {
                IIDXLevelShowcase(songRecord: songRecord)
            }
        }
    }
}
