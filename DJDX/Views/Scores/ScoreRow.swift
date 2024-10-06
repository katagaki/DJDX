//
//  ScoreRow.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/02.
//

import SwiftUI

struct ScoreRow: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @AppStorage(wrappedValue: false, "ScoresView.GenreVisible") var isGenreVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ArtistVisible") var isArtistVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.LevelVisible") var isLevelVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.DJLevelVisible") var isDJLevelVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ScoreRateVisible") var isScoreRateVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ScoreVisible") var isScoreVisible: Bool
    @AppStorage(wrappedValue: false, "ScoresView.LastPlayDateVisible") var isLastPlayDateVisible: Bool

    var namespace: Namespace.ID

    var songRecord: IIDXSongRecord
    @State var scoreRate: Float?

    @Binding var levelToShow: IIDXLevel
    @Binding var difficultyToShow: IIDXDifficulty

    var body: some View {
        let scores: [IIDXLevelScore?] = [
            songRecord.score(for: levelToShow),
            songRecord.score(for: difficultyToShow)
        ]
        VStack(alignment: .leading, spacing: 4.0) {
            HStack(alignment: .center, spacing: 8.0) {
                HStack(alignment: .center, spacing: 0.0) {
                    VStack(alignment: .leading, spacing: 2.0) {
                        if isGenreVisible {
                            Text(songRecord.genre)
                                .foregroundStyle(.secondary)
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
                        if isDJLevelVisible || isScoreRateVisible || isScoreVisible || isLastPlayDateVisible {
                            HStack(alignment: .center, spacing: 6.0) {
                                if let score = scores.first(where: { $0 != nil }), let score = score,
                                   score.score != 0 {
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
                                        if isScoreRateVisible {
                                            if let scoreRate {
                                                if isDJLevelVisible {
                                                    Divider()
                                                        .frame(maxHeight: 14.0)
                                                }
                                                Text(scoreRate, format: .percent.precision(.fractionLength(0)))
                                                    .foregroundStyle(LinearGradient(
                                                        colors: [.primary.opacity(0.55), .primary.opacity(0.3)],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    ))
                                                    .fontWidth(.expanded)
                                                    .fontWeight(.black)
                                            }
                                        }
                                        if isScoreVisible {
                                            if isDJLevelVisible || isScoreRateVisible {
                                                Divider()
                                                    .frame(maxHeight: 14.0)
                                            }
                                            Text(String(score.score))
                                                .foregroundStyle(LinearGradient(colors: [.cyan, .blue],
                                                                                startPoint: .top,
                                                                                endPoint: .bottom))
                                                .fontWidth(.expanded)
                                                .fontWeight(.heavy)
                                        }
                                    }
                                    .font(.caption)
                                    if isLastPlayDateVisible {
                                        if isDJLevelVisible || isScoreRateVisible || isScoreVisible {
                                            Divider()
                                                .frame(maxHeight: 14.0)
                                        }
                                        Text(RelativeDateTimeFormatter().localizedString(
                                            for: songRecord.lastPlayDate,
                                            relativeTo: .now
                                        ))
                                        .foregroundStyle(.secondary)
                                        .fontWidth(.condensed)
                                    }
                                }
                            }
                            .frame(minHeight: 0.0)
                            .offset(y: 1.0)
                            .font(.caption)
                        }
                    }
                    Spacer(minLength: 0.0)
                }
                .automaticMatchedTransitionSource(id: songRecord.title, in: namespace)
                if isLevelVisible, let score = scores.first(where: { $0 != nil }), let score = score {
                    IIDXLevelLabel(levelType: score.level, songRecord: songRecord)
                        .padding([.top, .bottom], 6.0)
                        .frame(width: 78.0, alignment: .center)
                        .background(colorScheme == .dark ?
                                    Color(uiColor: UIColor.secondarySystemGroupedBackground) :
                                        Color(uiColor: UIColor.systemGroupedBackground))
                        .clipShape(.rect(cornerRadius: 6.0))
                }
            }
            if isLevelVisible && levelToShow == .all && difficultyToShow == .all {
                HStack(alignment: .center, spacing: 8.0) {
                    Spacer(minLength: 0.0)
                    IIDXLevelShowcase(songRecord: songRecord)
                }
            }
        }
        .padding([.top, .bottom], 8.0)
        .safeAreaInset(edge: .leading) {
            VStack {
                if let score = scores.first(where: { $0 != nil }), let score = score {
                    switch score.clearType {
                    case "FULLCOMBO CLEAR":
                        LinearGradient(gradient: Gradient(colors: [Color.red,
                                                                   Color.orange,
                                                                   Color.yellow,
                                                                   Color.green,
                                                                   Color.blue,
                                                                   Color.indigo,
                                                                   Color.purple]),
                                       startPoint: .top,
                                       endPoint: .bottom)
                    case "CLEAR": Color.cyan
                    case "ASSIST CLEAR": Color.purple
                    case "EASY CLEAR": Color.green
                    case "HARD CLEAR": Color.pink
                    case "EX HARD CLEAR": Color.yellow
                    case "FAILED": Color.red
                    default: Color.clear
                    }
                } else {
                    Color.clear
                }
            }
            .frame(width: 12.0)
            .modifier(ConditionalShadow(color: .black.opacity(0.2), radius: 1.0, x: 2.0))
        }
    }
}
