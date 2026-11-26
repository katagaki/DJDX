import SwiftUI

struct IIDXScoreRow: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @AppStorage(wrappedValue: false, "ScoresView.GenreVisible") var isGenreVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ArtistVisible") var isArtistVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.LevelVisible") var isLevelVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.DJLevelVisible") var isDJLevelVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ScoreRateVisible") var isScoreRateVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ScoreVisible") var isScoreVisible: Bool
    @AppStorage(wrappedValue: false, "ScoresView.LastPlayDateVisible") var isLastPlayDateVisible: Bool
    @AppStorage(wrappedValue: IIDXVersion.zinrai, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    var namespace: Namespace.ID

    var songRecord: IIDXSongRecord
    var level: IIDXLevel
    var score: IIDXLevelScore
    @State var scoreRate: Float?
    var scoreDelta: Int?

    var body: some View {
        HStack(alignment: .center, spacing: 8.0) {
            // Leading Clear Lamp
            VStack {
                switch score.clearType {
                case "FULLCOMBO CLEAR":
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.red,
                            Color.orange,
                            Color.yellow,
                            Color.green,
                            Color.blue,
                            Color.indigo,
                            Color.purple
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                case "CLEAR": Color.cyan
                case "EASY CLEAR": Color.green
                case "ASSIST CLEAR": Color.purple
                case "HARD CLEAR": colorScheme == .dark ? Color.white : Color.gray
                case "EX HARD CLEAR": Color.orange
                case "FAILED": Color.red
                default: Color.clear
                }
            }
            .frame(width: 10.0)
            .frame(maxHeight: .infinity)
            .conditionalShadow(.black.opacity(0.2), radius: 1.0, x: 2.0)

            HStack(alignment: .center, spacing: 0.0) {
                // Song Info
                VStack(alignment: .leading, spacing: 2.0) {
                    if isGenreVisible {
                        Text(songRecord.genre)
                            .font(.caption2)
                            .fontWeight(.heavy)
                            .foregroundStyle(.white)
                            .strokeText(color: .black.opacity(0.7), width: 0.35)
                            .squashedHorizontally()
                    }
                    Text(songRecord.title)
                        .fontWeight(.heavy)
                        .fontWidth(.compressed)
                        .foregroundStyle(titleTextColor)
                        .strokeText(color: titleStrokeColor, width: colorScheme == .light ? 0.5 : 0.35)
                        .squashedHorizontally()
                    if isArtistVisible {
                        Text(songRecord.artist)
                            .font(.caption)
                            .fontWeight(.heavy)
                            .foregroundStyle(.white)
                            .strokeText(color: .black.opacity(0.7), width: 0.35)
                            .squashedHorizontally()
                    }
                    // Metadata Row
                    if isDJLevelVisible || isScoreRateVisible || isScoreVisible || isLastPlayDateVisible {
                        HStack(alignment: .center, spacing: 6.0) {
                            if score.score != 0 {
                                Group {
                                    if isDJLevelVisible {
                                        Text(score.djLevel)
                                            .foregroundStyle(IIDXDJLevel.style(for: score.djLevel))
                                            .fontWidth(.expanded)
                                            .fontWeight(.black)
                                            .strokeText(color: .black, width: 0.3)
                                    }
                                    if isScoreRateVisible, let scoreRate {
                                        if isDJLevelVisible {
                                            Divider()
                                                .frame(maxHeight: 14.0)
                                        }
                                        Text(scoreRate, format: .percent.precision(.fractionLength(1)))
                                            .foregroundStyle(LinearGradient(
                                                colors: [.primary.opacity(0.55), .primary.opacity(0.3)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ))
                                            .font(.scoreline(.caption))
                                    }
                                    if isScoreVisible {
                                        if isDJLevelVisible || isScoreRateVisible {
                                            Divider()
                                                .frame(maxHeight: 14.0)
                                        }
                                        Text(String(score.score))
                                            .foregroundStyle(Color.iidxScore)
                                            .font(.scoreline(.caption))
                                            .strokeText(color: .iidxScoreOutline, width: 0.3)
                                        if let scoreDelta, scoreDelta > 0 {
                                            Text("Analytics.NewHighScore.\(scoreDelta)")
                                                .foregroundStyle(.orange)
                                                .font(.scoreline(.caption))
                                        }
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
                        .offset(y: 1.0)
                        .font(.caption)
                    }
                }
                Spacer(minLength: 0.0)
            }
            .padding([.top, .bottom], 8.0)
            .matchedTransitionSource(id: "\(songRecord.title).\(level.rawValue)", in: namespace)

            // Level
            if isLevelVisible {
                IIDXLevelLabel(layout: .horizontal, levelType: level, score: score)
                    .padding([.top, .bottom], 8.0)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.trailing)
    }

    var titleTextColor: LinearGradient {
        iidxVersion.rowTitleTextColor(for: songRecord.version, level: level, colorScheme: colorScheme)
    }

    var titleStrokeColor: Color {
        iidxVersion.rowTitleStrokeColor(for: songRecord.version, level: level, colorScheme: colorScheme)
    }
}
