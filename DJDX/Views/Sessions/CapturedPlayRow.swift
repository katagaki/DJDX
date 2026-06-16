import SwiftUI

struct CapturedPlayRow: View {
    var play: CapturedPlay

    var body: some View {
        HStack(spacing: 12.0) {
            stateBadge
            VStack(alignment: .leading, spacing: 2.0) {
                Text(verbatim: play.songTitle ?? String(localized: "Sessions.UnknownSong"))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 6.0) {
                    Text(verbatim: chartLabel)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                    if play.clearType != IIDXClearType.noPlay.rawValue {
                        Text(verbatim: IIDXClearType.abbreviation(for: play.clearType))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(IIDXClearType.color(for: play.clearType))
                    }
                    if play.djLevel != IIDXDJLevel.none.rawValue {
                        Text(verbatim: play.djLevel)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(IIDXDJLevel.color(for: play.djLevel))
                    }
                }
            }
            Spacer()
            if play.exScore > 0 {
                Text(verbatim: "\(play.exScore)")
                    .font(.callout.monospacedDigit().weight(.semibold))
            }
        }
        .padding(.vertical, 2.0)
    }

    private var chartLabel: String {
        let code = play.level.code()
        let style = play.playType.displayName()
        if play.difficulty > 0 {
            return "\(style)\(code.isEmpty ? "" : code) ☆\(play.difficulty)"
        }
        return "\(style)\(code.isEmpty ? "" : " \(code)")"
    }

    @ViewBuilder
    private var stateBadge: some View {
        switch play.state {
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case .processing:
            ProgressView()
                .controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .needsReview:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
