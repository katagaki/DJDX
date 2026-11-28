import SwiftUI

struct IIDXCompactResultSummary: View {
    let djLevel: String
    let clearType: String
    let score: Int
    let scoreRate: Float?

    var body: some View {
        HStack(alignment: .center, spacing: 12.0) {
            Text(verbatim: djLevel)
                .font(.largeTitle)
                .fontWidth(.expanded)
                .fontWeight(.black)
                .foregroundStyle(IIDXDJLevel.style(for: djLevel))
                .strokeText(color: .black, width: 0.6)
            VStack(alignment: .leading, spacing: 3.0) {
                IIDXMetallicText.clearType(clearType)
                    .font(.caption)
                if let scoreRate {
                    Text(scoreRate, format: .percent.precision(.fractionLength(1)))
                        .font(.scoreline(.caption))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8.0)
            IIDXScoreText(score, style: .title)
        }
    }
}

struct IIDXCompactJudgments: View {
    var entries: [(judgment: IIDXJudgment, value: Int)]

    private var size: CGFloat { entries.count <= 3 ? 21.0 : 19.0 }
    private var outlineScale: CGFloat { size * 0.02 }

    var body: some View {
        HStack(alignment: .top, spacing: 0.0) {
            ForEach(entries.indices, id: \.self) { index in
                VStack(spacing: 6.0) {
                    IIDXJudgmentLabel(judgment: entries[index].judgment, size: size, outlineScale: outlineScale)
                    IIDXJudgmentLabel(judgment: entries[index].judgment,
                                      text: String(entries[index].value), size: size, outlineScale: outlineScale)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
