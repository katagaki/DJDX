import ActivityKit
import SwiftUI
import WidgetKit

struct SessionLiveActivityView: View {
    let context: ActivityViewContext<SessionActivityAttributes>

    static let captureURL = URL(string: "djdx://session?action=capture")!

    var body: some View {
        HStack(spacing: 14.0) {
            GameIconImage(assetName: context.attributes.gameIconAssetName, size: 26.0)
            VStack(alignment: .leading, spacing: 2.0) {
                Text(verbatim: context.state.lastSongTitle ?? context.attributes.gameShortName)
                    .font(.headline)
                    .lineLimit(1)
                if let summary = context.state.lastResultSummary {
                    Text(verbatim: summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2.0) {
                Text(verbatim: "\(context.state.playCount)")
                    .font(.title2.monospacedDigit().weight(.bold))
                Text("Sessions.Plays")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            CaptureButton()
        }
        .padding()
        .activityBackgroundTint(.clear)
    }
}

struct CaptureButton: View {
    var size: CGFloat = 22.0

    var body: some View {
        Link(destination: SessionLiveActivityView.captureURL) {
            Image(systemName: "camera.fill")
                .font(.system(size: size * 0.6, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: size + 18.0, height: size + 18.0)
                .background(.thinMaterial, in: Circle())
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
                    .font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let heartRate = context.state.heartRate {
                        Label("\(heartRate)", systemImage: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2.0) {
                            Text(verbatim: context.state.lastSongTitle ?? "—")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            if let summary = context.state.lastResultSummary {
                                Text(verbatim: summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(verbatim: "\(context.state.playCount)")
                            .font(.title3.monospacedDigit().weight(.bold))
                        CaptureButton(size: 18.0)
                    }
                }
            } compactLeading: {
                GameIconImage(assetName: context.attributes.gameIconAssetName, size: 18.0)
            } compactTrailing: {
                Text(verbatim: "\(context.state.playCount)")
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
