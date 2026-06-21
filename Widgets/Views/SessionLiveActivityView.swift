import ActivityKit
import SwiftUI
import WidgetKit

struct SessionLiveActivityView: View {
    let context: ActivityViewContext<SessionActivityAttributes>

    static let captureURL = URL(string: "djdx://session?action=capture")!

    var body: some View {
        HStack(spacing: 14.0) {
            GameIconImage(assetName: context.attributes.gameIconAssetName, size: 36.0)
            SessionResultLabel(
                title: context.state.lastSongTitle ?? context.attributes.gameShortName,
                rank: context.state.lastDJLevel,
                clearType: context.state.lastClearType,
                score: context.state.lastScore,
                detailLayout: .stacked,
                titleSpacing: 7.0,
                titleSize: 20.0
            )
            Spacer()
            VStack(alignment: .trailing, spacing: 2.0) {
                Text(verbatim: "\(context.state.playCount)")
                    .font(.system(size: 22.0, weight: .bold).monospacedDigit())
                Text("Sessions.Plays")
                    .font(.system(size: 11.0))
                    .foregroundStyle(.secondary)
            }
            CaptureButton(size: 36.0)
        }
        .padding()
        .activityBackgroundTint(.clear)
    }
}

enum SessionResultDetailLayout {
    case inline, stacked
}

struct SessionResultLabel: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    var rank: String?
    var clearType: String?
    var score: Int?
    var alignment: HorizontalAlignment = .leading
    var detailLayout: SessionResultDetailLayout = .inline
    var titleSpacing: CGFloat = 3.0
    var titleSize: CGFloat = 17.0
    var rankSize: CGFloat = 15.0
    var detailSize: CGFloat = 12.0

    var body: some View {
        VStack(alignment: alignment, spacing: titleSpacing) {
            Text(verbatim: title)
                .font(.system(size: titleSize, weight: .heavy))
                .fontWidth(.compressed)
                .lineLimit(1)
            if rank != nil || clearType != nil || score != nil {
                switch detailLayout {
                case .inline: inlineDetails
                case .stacked: stackedDetails
                }
            }
        }
    }

    private var inlineDetails: some View {
        HStack(spacing: 6.0) {
            if let rank {
                RankText(rank: rank, size: rankSize)
            }
            if let clearType {
                Text(verbatim: clearTypeAbbreviation(clearType))
                    .foregroundStyle(clearTypeStyle(clearType))
            }
            if clearType != nil, score != nil {
                Text(verbatim: "·")
                    .foregroundStyle(.secondary)
            }
            if let score {
                Text(verbatim: "\(score)")
                    .monospacedDigit()
                    .foregroundStyle(scoreStyle)
            }
        }
        .font(.system(size: detailSize, weight: .heavy))
        .fontWidth(.expanded)
        .lineLimit(1)
    }

    private var stackedDetails: some View {
        HStack(spacing: 8.0) {
            if let rank {
                RankText(rank: rank, size: 34.0)
            }
            VStack(alignment: .leading, spacing: 3.0) {
                if let clearType {
                    Text(verbatim: clearTypeAbbreviation(clearType))
                        .foregroundStyle(clearTypeStyle(clearType))
                }
                if let score {
                    Text(verbatim: "\(score)")
                        .monospacedDigit()
                        .foregroundStyle(scoreStyle)
                }
            }
            .font(.system(size: detailSize, weight: .heavy))
            .fontWidth(.expanded)
            .lineLimit(1)
        }
    }

    private var scoreStyle: LinearGradient {
        LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
    }

    private func clearTypeAbbreviation(_ clearType: String) -> String {
        switch clearType {
        case "FULLCOMBO CLEAR": return "F-COMBO"
        case "CLEAR": return "CLEAR"
        case "EASY CLEAR": return "E-CLEAR"
        case "ASSIST CLEAR": return "A-CLEAR"
        case "HARD CLEAR": return "H-CLEAR"
        case "EX HARD CLEAR": return "EXH-CLEAR"
        case "FAILED": return "FAIL"
        default: return clearType
        }
    }

    private func clearTypeStyle(_ clearType: String) -> AnyShapeStyle {
        func whiteOr(_ color: Color) -> Color { colorScheme == .dark ? .white : color }
        switch clearType {
        case "FULLCOMBO CLEAR":
            return AnyShapeStyle(LinearGradient(colors: [.cyan, whiteOr(.blue), .purple],
                                                startPoint: .top, endPoint: .bottom))
        case "FAILED":
            return AnyShapeStyle(LinearGradient(colors: [.orange, .red, .orange],
                                                startPoint: .top, endPoint: .bottom))
        case "EASY CLEAR":
            return AnyShapeStyle(LinearGradient(colors: [whiteOr(.mint), .green, whiteOr(.mint)],
                                                startPoint: .top, endPoint: .bottom))
        case "ASSIST CLEAR":
            return AnyShapeStyle(LinearGradient(colors: [whiteOr(.indigo), .purple, whiteOr(.indigo)],
                                                startPoint: .top, endPoint: .bottom))
        case "CLEAR":
            return AnyShapeStyle(LinearGradient(colors: [whiteOr(.blue), .cyan, whiteOr(.blue)],
                                                startPoint: .top, endPoint: .bottom))
        case "HARD CLEAR":
            return AnyShapeStyle(LinearGradient(colors: [whiteOr(.red), .pink, whiteOr(.red)],
                                                startPoint: .top, endPoint: .bottom))
        case "EX HARD CLEAR":
            return AnyShapeStyle(LinearGradient(colors: [whiteOr(.orange), .yellow, whiteOr(.orange)],
                                                startPoint: .top, endPoint: .bottom))
        default:
            return AnyShapeStyle(.primary)
        }
    }
}

struct RankText: View {
    @Environment(\.colorScheme) private var colorScheme

    let rank: String
    var size: CGFloat = 20.0

    var body: some View {
        Text(verbatim: rank)
            .font(.system(size: size, weight: .black))
            .fontWidth(.expanded)
            .foregroundStyle(djLevelStyle)
    }

    private var djLevelStyle: LinearGradient {
        switch colorScheme {
        case .dark:
            return LinearGradient(colors: [.white, .cyan], startPoint: .top, endPoint: .bottom)
        default:
            return LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
        }
    }
}

struct CaptureButton: View {
    var size: CGFloat = 22.0

    var body: some View {
        Link(destination: SessionLiveActivityView.captureURL) {
            Image(systemName: "camera.fill")
                .font(.system(size: size * 0.6, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size + 18.0, height: size + 18.0)
                .background(Color("AccentColor"), in: Circle())
        }
    }
}

struct SessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            SessionLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(verbatim: context.attributes.gameShortName)
                    } icon: {
                        GameIconImage(assetName: context.attributes.gameIconAssetName, size: 16.0)
                    }
                    .font(.system(size: 12.0))
                    .padding(.leading, 4.0)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 4.0) {
                        Text(verbatim: "\(context.state.playCount)")
                            .monospacedDigit()
                            .fontWeight(.bold)
                        Text("Sessions.Plays")
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 12.0))
                    .lineLimit(1)
                    .padding(.trailing, 4.0)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8.0) {
                        SessionResultLabel(
                            title: context.state.lastSongTitle ?? context.attributes.gameShortName,
                            clearType: context.state.lastClearType,
                            score: context.state.lastScore,
                            titleSize: 15.0,
                            detailSize: 11.0
                        )
                        Spacer()
                        if let rank = context.state.lastDJLevel {
                            RankText(rank: rank, size: 22.0)
                        }
                    }
                    .padding(.horizontal, 4.0)
                    .padding(.top, 6.0)
                }
            } compactLeading: {
                GameIconImage(assetName: context.attributes.gameIconAssetName, size: 18.0)
            } compactTrailing: {
                Text(verbatim: "\(context.state.playCount)")
                    .font(.system(size: 16.0, weight: .semibold))
                    .monospacedDigit()
            } minimal: {
                GameIconImage(assetName: context.attributes.gameIconAssetName, size: 18.0)
            }
        }
    }
}

struct GameIconImage: View {
    let assetName: String
    var size: CGFloat = 24.0

    var body: some View {
        Image(assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
    }
}
