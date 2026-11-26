import SwiftUI

struct AnalyticsSuggestionPreview: Identifiable {
    let id: UUID
    let title: String
    let detail: String
    let value: String
    var badge: LevelBadge?
    var detailLabel: IIDXMetallicText?
}

struct AnalyticsSuggestionCard: View {

    let title: Text
    let systemImage: String
    let iconColor: Color
    let count: Int
    let previews: [AnalyticsSuggestionPreview]

    var cornerRadius: CGFloat {
        if #available(iOS 26.0, *) {
            return 20.0
        } else {
            return 12.0
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            HStack(spacing: 5.0) {
                Image(systemName: systemImage)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(iconColor)
                    .frame(width: 12.0, height: 12.0)
                title
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0.0)
                Text(verbatim: "\(count)")
                    .font(.scoreline(.caption, weight: .bold))
                    .fontWidth(.standard)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            ZStack(alignment: .top) {
                previewRows(placeholders)
                    .hidden()
                if previews.isEmpty {
                    Text("Analytics.Suggestions.Empty")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    previewRows(previews)
                }
            }
        }
        .padding(12.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(cornerRadius: cornerRadius)
    }

    private var placeholders: [AnalyticsSuggestionPreview] {
        (0..<Self.previewLimit).map { _ in
            AnalyticsSuggestionPreview(id: UUID(), title: " ", detail: " ", value: " ")
        }
    }

    static let previewLimit = 3

    private func previewRows(_ rows: [AnalyticsSuggestionPreview]) -> some View {
        VStack(alignment: .leading, spacing: 6.0) {
            ForEach(rows) { preview in
                HStack(alignment: .firstTextBaseline, spacing: 8.0) {
                    VStack(alignment: .leading, spacing: 0.0) {
                        Text(preview.title)
                            .font(.subheadline.bold())
                            .fontWidth(.condensed)
                            .lineLimit(1)
                        Group {
                            if let detailLabel = preview.detailLabel {
                                detailLabel
                            } else {
                                Text(verbatim: preview.detail)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption2)
                        .lineLimit(1)
                    }
                    Spacer(minLength: 0.0)
                    if let badge = preview.badge {
                        badge
                            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4.0 }
                    } else {
                        Text(verbatim: preview.value)
                            .font(.scoreline(.subheadline))
                            .fontWidth(.standard)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}

struct AnalyticsSuggestionLevelLabel: View {
    let difficulty: String
    let color: Color
    let level: String

    var body: some View {
        LevelBadge(name: difficulty, level: level, tint: color)
    }
}

struct AnalyticsSuggestionRow: View {
    let title: String
    let current: String
    let target: String
    let detail: String
    let gain: String
    let difficulty: String
    let difficultyColor: Color
    let level: String
    var currentLabel: IIDXMetallicText?
    var targetLabel: IIDXMetallicText?
    var scores: (current: Int, target: Int?)?

    var body: some View {
        HStack(alignment: .center, spacing: 8.0) {
            VStack(alignment: .leading, spacing: 2.0) {
                Text(title)
                    .bold()
                    .fontWidth(.condensed)
                HStack(spacing: 4.0) {
                    if let currentLabel {
                        currentLabel
                    } else {
                        Text(verbatim: current)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let targetLabel {
                        targetLabel
                    } else {
                        Text(verbatim: target)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                    if !gain.isEmpty {
                        Text(verbatim: gain)
                            .font(.scoreline(.caption))
                            .fontWidth(.standard)
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .fontWidth(.expanded)
                if let scores {
                    HStack(spacing: 4.0) {
                        Text(verbatim: "EX SCORE")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        scoreText(scores.current)
                        if let target = scores.target {
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            scoreText(target)
                        }
                    }
                } else if !detail.isEmpty {
                    Text(verbatim: detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0.0)
            AnalyticsSuggestionLevelLabel(difficulty: difficulty, color: difficultyColor, level: level)
        }
        .padding(.vertical, 2.0)
        .listRowBackground(Color.clear)
    }

    private func scoreText(_ score: Int) -> some View {
        IIDXScoreText(score)
    }
}
