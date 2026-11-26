import SwiftUI

struct ImportSummaryEntryRow: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    let entry: ImportSummaryEntry
    let game: ImportSummaryGame

    var body: some View {
        HStack(alignment: .center, spacing: 8.0) {
            Rectangle()
                .fill(entry.lampStyle)
                .frame(width: 10.0)
                .frame(maxHeight: .infinity)
                .conditionalShadow(.black.opacity(0.2), radius: 1.0, x: 2.0)

            VStack(alignment: .leading, spacing: 2.0) {
                Text(verbatim: entry.title)
                    .fontWeight(.heavy)
                    .fontWidth(.compressed)
                    .squashedHorizontally()
                metadata()
                    .offset(y: 1.0)
            }
            .padding([.top, .bottom], 8.0)

            Spacer(minLength: 0.0)

            levelLabel()
                .padding([.top, .bottom], 6.0)
                .frame(width: 78.0, alignment: .center)
                .cardBackground(cornerRadius: 6.0)
                .padding([.top, .bottom], 8.0)
        }
        .frame(maxWidth: .infinity)
        .padding(.trailing)
    }

    @ViewBuilder
    func metadata() -> some View {
        HStack(alignment: .center, spacing: 6.0) {
            if let grade = entry.grade {
                styledValue(grade)
                    .fontWidth(.expanded)
                    .fontWeight(.black)
            }
            if let score = entry.score {
                if entry.grade != nil {
                    separator()
                }
                scoreText(scoreString(score))
                    .fontWidth(.expanded)
                    .fontWeight(.heavy)
                if let previousScore = entry.previousScore {
                    Text(verbatim: "(+\(scoreString(score - previousScore)))")
                        .foregroundStyle(.orange)
                        .fontWidth(.expanded)
                        .fontWeight(.heavy)
                }
            }
            if let lamp = entry.lamp {
                if entry.grade != nil || entry.score != nil {
                    separator()
                }
                styledValue(lamp)
                    .fontWidth(.expanded)
                    .fontWeight(.heavy)
            }
        }
        .font(.caption)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    @ViewBuilder
    func separator() -> some View {
        Divider()
            .frame(maxHeight: 14.0)
    }

    @ViewBuilder
    func levelLabel() -> some View {
        VStack(alignment: .center) {
            Text(verbatim: entry.level)
                .italic()
                .font(.system(size: 16.0))
                .fontWeight(.black)
            Text(verbatim: entry.difficulty)
                .font(.system(size: 10.0))
                .fontWeight(.semibold)
        }
        .kerning(-0.2)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .drawingGroup()
        .offset(y: -1.5)
        .modifier(LevelLabelGlow(color: entry.difficultyColor))
    }

    @ViewBuilder
    func scoreText(_ value: String) -> some View {
        switch game {
        case .iidx:
            Text(verbatim: value)
                .foregroundStyle(Color.iidxScore)
                .strokeText(color: .iidxScoreOutline, width: 0.3)
        case .sdvx:
            Text(verbatim: value)
                .sdvxScoreText()
        case .polarisChord, .ddr:
            Text(verbatim: value)
                .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
        }
    }

    @ViewBuilder
    func styledValue(_ change: ImportSummaryChange) -> some View {
        switch change.style {
        case .iidxClearType:
            Text(verbatim: IIDXClearType.abbreviation(for: change.current))
                .foregroundStyle(IIDXClearType.color(for: change.current))
        case .iidxDJLevel:
            Text(verbatim: change.current)
                .foregroundStyle(IIDXDJLevel.style(for: change.current))
                .strokeText(color: .black, width: 0.3)
        case .sdvxGrade:
            Text(verbatim: change.current)
                .sdvxGradeText()
        case .polarisChordGrade:
            let style = (PolarisChordGrade(rawValue: change.current) ?? .none).style(colorScheme: colorScheme)
            Text(verbatim: change.current)
                .foregroundStyle(style)
        case .color(let color):
            Text(verbatim: change.current)
                .foregroundStyle(color)
        }
    }

    func scoreString(_ value: Int) -> String {
        switch game {
        case .sdvx, .polarisChord: return value.formatted(.number)
        case .iidx, .ddr: return String(value)
        }
    }
}
