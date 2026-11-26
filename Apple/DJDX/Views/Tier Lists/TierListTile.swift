import SwiftUI

struct TierListTile: View {

    let chart: TierListChart

    static let width: CGFloat = 143.0

    var body: some View {
        HStack(spacing: 0.0) {
            Rectangle()
                .fill(chart.lampColor)
                .frame(width: 5.0)
            VStack(alignment: .leading, spacing: 2.0) {
                HStack(alignment: .center, spacing: 4.0) {
                    levelLabel
                    Spacer(minLength: 0.0)
                    if !chart.grade.isEmpty {
                        Text(chart.grade)
                            .font(.caption)
                            .fontWidth(.expanded)
                            .fontWeight(.black)
                            .foregroundStyle(gradeStyle)
                            .strokeText(color: .black, width: 0.3)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
                Text(chart.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .fontWidth(.compressed)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 6.0)
            .padding(.vertical, 4.0)
        }
        .frame(width: Self.width, alignment: .leading)
        .background(.background.secondary)
        .clipShape(.rect(cornerRadius: 6.0))
        .overlay {
            RoundedRectangle(cornerRadius: 6.0)
                .stroke(chart.lampColor.opacity(0.5), lineWidth: 1.0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(chart.lampLabel)
    }

    @ViewBuilder
    var levelLabel: some View {
        if let iidxLevel = chart.iidxLevel {
            IIDXLevelLabel(
                orientation: .horizontal,
                levelType: iidxLevel,
                score: IIDXLevelScore(level: iidxLevel, difficulty: Int(chart.level) ?? 0)
            )
            .minimumScaleFactor(0.6)
        } else {
            HStack(alignment: .center, spacing: 6.0) {
                Text(chart.level)
                    .italic()
                    .font(.system(size: 14.0))
                    .fontWeight(.black)
                Text(chart.difficultyLabel)
                    .font(.system(size: 10.0))
                    .fontWeight(.semibold)
            }
            .kerning(-0.2)
            .lineLimit(1)
            .modifier(LevelLabelGlow(color: chart.difficultyColor))
        }
    }

    var gradeStyle: AnyShapeStyle {
        chart.iidxLevel != nil ? AnyShapeStyle(IIDXDJLevel.style(for: chart.grade)) : AnyShapeStyle(chart.gradeColor)
    }
}
