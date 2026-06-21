import SwiftUI

struct WatchSessionResultLabel: View {
    let title: String
    var rank: String?
    var clearType: String?
    var score: Int?
    var fallbackSummary: String?

    private var hasResult: Bool {
        rank != nil || clearType != nil || score != nil
    }

    var body: some View {
        VStack(spacing: 4.0) {
            Text(verbatim: title)
                .font(.footnote.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            if hasResult {
                HStack(spacing: 8.0) {
                    if let rank {
                        WatchRankText(rank: rank, size: 28.0)
                    }
                    VStack(alignment: .leading, spacing: 1.0) {
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
                    .font(.caption2.weight(.heavy))
                    .lineLimit(1)
                }
            } else if let fallbackSummary {
                Text(verbatim: fallbackSummary)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
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
        switch clearType {
        case "FULLCOMBO CLEAR":
            return AnyShapeStyle(LinearGradient(colors: [.cyan, .white, .purple],
                                                startPoint: .top, endPoint: .bottom))
        case "FAILED":
            return AnyShapeStyle(LinearGradient(colors: [.orange, .red, .orange],
                                                startPoint: .top, endPoint: .bottom))
        case "EASY CLEAR":
            return AnyShapeStyle(LinearGradient(colors: [.mint, .green, .mint],
                                                startPoint: .top, endPoint: .bottom))
        case "ASSIST CLEAR":
            return AnyShapeStyle(LinearGradient(colors: [.indigo, .purple, .indigo],
                                                startPoint: .top, endPoint: .bottom))
        case "CLEAR":
            return AnyShapeStyle(LinearGradient(colors: [.white, .cyan, .white],
                                                startPoint: .top, endPoint: .bottom))
        case "HARD CLEAR":
            return AnyShapeStyle(LinearGradient(colors: [.red, .pink, .red],
                                                startPoint: .top, endPoint: .bottom))
        case "EX HARD CLEAR":
            return AnyShapeStyle(LinearGradient(colors: [.orange, .yellow, .orange],
                                                startPoint: .top, endPoint: .bottom))
        default:
            return AnyShapeStyle(.primary)
        }
    }
}

struct WatchRankText: View {
    let rank: String
    var size: CGFloat = 20.0

    var body: some View {
        Text(verbatim: rank)
            .font(.system(size: size, weight: .black))
            .fontWidth(.expanded)
            .foregroundStyle(LinearGradient(colors: [.white, .cyan], startPoint: .top, endPoint: .bottom))
    }
}
