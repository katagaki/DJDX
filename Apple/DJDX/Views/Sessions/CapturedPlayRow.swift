import SwiftUI

struct CapturedPlayRow: View {
    var play: IIDXCapturedPlay

    @Namespace private var namespace

    var body: some View {
        if play.state == .done || play.state == .needsReview {
            IIDXScoreRow(
                namespace: namespace,
                songRecord: songRecord,
                level: play.level == .unknown ? .another : play.level,
                score: play.levelScore(),
                scoreRate: nil
            )
            .overlay(alignment: .topTrailing) {
                if play.state == .needsReview {
                    reviewBadge
                        .padding(.trailing, 8.0)
                }
            }
        } else {
            statusRow
        }
    }

    private var reviewBadge: some View {
        Image(systemName: "exclamationmark")
            .font(.system(size: 10.0, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 16.0, height: 16.0)
            .background(.orange, in: Circle())
            .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1.0)
    }

    private var songRecord: IIDXSongRecord {
        let record = IIDXSongRecord()
        record.title = play.songTitle ?? String(localized: "Sessions.UnknownSong")
        record.playType = play.playType
        record.lastPlayDate = play.captureDate
        return record
    }

    private var statusRow: some View {
        HStack(alignment: .center, spacing: 8.0) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 10.0)
                .frame(maxHeight: .infinity)
            Text(verbatim: play.songTitle ?? String(localized: "Sessions.UnknownSong"))
                .bold()
                .fontWidth(.condensed)
                .lineLimit(1)
                .padding(.vertical, 16.0)
            Spacer(minLength: 8.0)
            HStack(spacing: 6.0) {
                stateIcon
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.trailing)
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch play.state {
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case .processing:
            ProgressView()
                .controlSize(.small)
        default:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private var statusText: LocalizedStringKey {
        switch play.state {
        case .pending: "Sessions.State.Pending"
        case .processing: "Sessions.State.Processing"
        default: "Sessions.State.Failed"
        }
    }
}
