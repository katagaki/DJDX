import SwiftUI

struct CapturedPlayRow: View {
    var play: CapturedPlay

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
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .padding(6.0)
                }
            }
        } else {
            statusRow
        }
    }

    private var songRecord: IIDXSongRecord {
        let record = IIDXSongRecord()
        record.title = play.songTitle ?? String(localized: "Sessions.UnknownSong")
        record.playType = play.playType
        record.lastPlayDate = play.captureDate
        return record
    }

    private var statusRow: some View {
        HStack(spacing: 12.0) {
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
            Text(verbatim: play.songTitle ?? String(localized: "Sessions.UnknownSong"))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer()
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8.0)
        .padding(.trailing)
    }

    private var statusText: LocalizedStringKey {
        switch play.state {
        case .pending: "Sessions.State.Pending"
        case .processing: "Sessions.State.Processing"
        default: "Sessions.State.Failed"
        }
    }
}
