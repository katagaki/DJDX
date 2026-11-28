import SwiftUI

struct IIDXScoreRow<Accessory: View>: View {

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
    var scoreRate: Float?
    var scoreDelta: Int?
    var accessory: Accessory
    var showsMetadata: Bool = true
    var showsGenre: Bool = true
    var showsScore: Bool = true
    var showsLastPlayDate: Bool = true
    var isAccessoryInline: Bool = false
    var verticalPadding: CGFloat = 8.0

    init(namespace: Namespace.ID, songRecord: IIDXSongRecord, level: IIDXLevel, score: IIDXLevelScore,
         scoreRate: Float? = nil, scoreDelta: Int? = nil, @ViewBuilder accessory: () -> Accessory) {
        self.namespace = namespace
        self.songRecord = songRecord
        self.level = level
        self.score = score
        self.scoreRate = scoreRate
        self.scoreDelta = scoreDelta
        self.accessory = accessory()
    }

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
                    if showsGenre && isGenreVisible && !songRecord.genre.isEmpty {
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
                    if isArtistVisible && !songRecord.artist.isEmpty {
                        Text(songRecord.artist)
                            .font(.caption)
                            .fontWeight(.heavy)
                            .foregroundStyle(.white)
                            .strokeText(color: .black.opacity(0.7), width: 0.35)
                            .squashedHorizontally()
                    }
                    // Metadata Row
                    let showsAnyScoreField = isDJLevelVisible || isScoreRateVisible
                        || (showsScore && isScoreVisible) || (showsLastPlayDate && isLastPlayDateVisible)
                    if showsMetadata, (score.score != 0 && showsAnyScoreField) || isAccessoryInline {
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
                                            .fontWidth(.standard)
                                    }
                                    if showsScore && isScoreVisible {
                                        if isDJLevelVisible || isScoreRateVisible {
                                            Divider()
                                                .frame(maxHeight: 14.0)
                                        }
                                        IIDXScoreText(score.score)
                                        if let scoreDelta, scoreDelta > 0 {
                                            Text("Analytics.NewHighScore.\(scoreDelta)")
                                                .foregroundStyle(.orange)
                                                .font(.scoreline(.caption))
                                                .fontWidth(.standard)
                                        }
                                    }
                                }
                                .font(.caption)
                                if showsLastPlayDate && isLastPlayDateVisible {
                                    if isDJLevelVisible || isScoreRateVisible || (showsScore && isScoreVisible) {
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
                            if isAccessoryInline {
                                accessory
                                    .font(.caption)
                            }
                        }
                        .offset(y: 1.0)
                        .font(.caption)
                    }
                    if !isAccessoryInline {
                        accessory
                            .font(.caption)
                    }
                }
                Spacer(minLength: 0.0)
            }
            .padding([.top, .bottom], verticalPadding)

            // Level
            if isLevelVisible {
                IIDXLevelLabel(layout: .horizontal, levelType: level, score: score)
                    .padding([.top, .bottom], verticalPadding)
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

extension IIDXScoreRow where Accessory == EmptyView {
    init(namespace: Namespace.ID, songRecord: IIDXSongRecord, level: IIDXLevel, score: IIDXLevelScore,
         scoreRate: Float? = nil, scoreDelta: Int? = nil) {
        self.init(namespace: namespace, songRecord: songRecord, level: level, score: score,
                  scoreRate: scoreRate, scoreDelta: scoreDelta) { EmptyView() }
    }
}
