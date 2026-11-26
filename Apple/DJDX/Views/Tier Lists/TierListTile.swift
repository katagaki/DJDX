import SwiftUI

struct TierListTile: View {

    @Environment(\.colorScheme) var colorScheme
    @AppStorage(wrappedValue: IIDXVersion.zinrai, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    let chart: TierListChart

    static let width: CGFloat = 138.0

    var body: some View {
        HStack(spacing: 0.0) {
            Rectangle()
                .fill(chart.lampColor)
                .frame(width: 5.0)
            VStack(alignment: .leading, spacing: 2.0) {
                title
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
            }
            .padding(.horizontal, 6.0)
            .padding(.vertical, 4.0)
        }
        .frame(width: Self.width, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 10.0))
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

    @ViewBuilder
    var title: some View {
        if let iidxLevel = chart.iidxLevel {
            Text(chart.title)
                .font(.subheadline)
                .fontWeight(.heavy)
                .fontWidth(.compressed)
                .foregroundStyle(
                    iidxVersion.rowTitleTextColor(for: chart.songVersion, level: iidxLevel, colorScheme: colorScheme)
                )
                .strokeText(
                    color: iidxVersion.rowTitleStrokeColor(
                        for: chart.songVersion, level: iidxLevel, colorScheme: colorScheme
                    ),
                    width: colorScheme == .light ? 0.5 : 0.35
                )
                .squashedHorizontally()
        } else {
            Text(chart.title)
                .font(.subheadline)
                .bold()
                .squashedHorizontally()
        }
    }

    var gradeStyle: AnyShapeStyle {
        chart.iidxLevel != nil ? AnyShapeStyle(IIDXDJLevel.style(for: chart.grade)) : AnyShapeStyle(chart.gradeColor)
    }
}
