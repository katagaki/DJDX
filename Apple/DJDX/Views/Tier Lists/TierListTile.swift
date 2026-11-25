import SwiftUI

struct TierListTile: View {

    let chart: TierListChart

    static let width: CGFloat = 143.0

    var body: some View {
        HStack(spacing: 0.0) {
            Rectangle()
                .fill(chart.lampColor)
                .frame(width: 5.0)
            levelLabel
                .frame(width: 54.0)
            Text(chart.title)
                .font(.caption)
                .fontWeight(.semibold)
                .fontWidth(.compressed)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 36.0, alignment: .leading)
                .padding(.vertical, 4.0)
                .padding(.leading, 2.0)
            if !chart.grade.isEmpty {
                Text(chart.grade)
                    .font(.caption)
                    .fontWidth(.expanded)
                    .fontWeight(.black)
                    .foregroundStyle(gradeStyle)
                    .strokeText(color: .black, width: 0.3)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.leading, 4.0)
            }
        }
        .padding(.trailing, 6.0)
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
                levelType: iidxLevel,
                score: IIDXLevelScore(level: iidxLevel, difficulty: Int(chart.level) ?? 0)
            )
            .minimumScaleFactor(0.7)
        } else {
            VStack(alignment: .center) {
                Text(chart.level)
                    .italic()
                    .font(.system(size: 16.0))
                    .fontWeight(.black)
                Text(chart.difficultyLabel)
                    .font(.system(size: 10.0))
                    .fontWeight(.semibold)
            }
            .kerning(-0.2)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .modifier(LevelLabelGlow(color: chart.difficultyColor))
        }
    }

    var gradeStyle: AnyShapeStyle {
        chart.iidxLevel != nil ? AnyShapeStyle(IIDXDJLevel.style(for: chart.grade)) : AnyShapeStyle(chart.gradeColor)
    }
}
