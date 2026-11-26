import SwiftUI

struct ImportSummaryEntryRow: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @AppStorage(wrappedValue: IIDXVersion.zinrai, "Global.IIDX.Version") var iidxVersion: IIDXVersion

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
                title()
                metadata()
                    .offset(y: 1.0)
            }
            .padding([.top, .bottom], 8.0)

            Spacer(minLength: 0.0)

            LevelBadge(name: entry.difficulty, level: entry.level,
                       tint: entry.difficultyColor, layout: .horizontal)
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
                    .font(.scoreline(.caption))
                    .fontWidth(.standard)
                if let previousScore = entry.previousScore {
                    Text(verbatim: "(+\(scoreString(score - previousScore)))")
                        .foregroundStyle(.orange)
                        .font(.scoreline(.caption))
                        .fontWidth(.standard)
                }
            }
            if let lamp = entry.lamp {
                if entry.grade != nil || entry.score != nil {
                    separator()
                }
                styledValue(lamp)
                    .fontWidth(.expanded)
                    .fontWeight(.bold)
            }
        }
        .font(.caption)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    @ViewBuilder
    func title() -> some View {
        switch entry.titleStyle {
        case .iidx(let version, let level):
            Text(verbatim: entry.title)
                .fontWeight(.heavy)
                .fontWidth(.compressed)
                .foregroundStyle(iidxVersion.rowTitleTextColor(for: version, level: level, colorScheme: colorScheme))
                .strokeText(
                    color: iidxVersion.rowTitleStrokeColor(for: version, level: level, colorScheme: colorScheme),
                    width: colorScheme == .light ? 0.5 : 0.35
                )
                .squashedHorizontally()
        case .plain:
            Text(verbatim: entry.title)
                .bold()
                .squashedHorizontally()
        }
    }

    @ViewBuilder
    func separator() -> some View {
        Divider()
            .frame(maxHeight: 14.0)
    }

    @ViewBuilder
    func scoreText(_ value: String) -> some View {
        switch game {
        case .iidx:
            IIDXScoreText(text: value)
        case .sdvx:
            Text(verbatim: value)
                .sdvxScoreText()
        case .polarisChord, .gitadora:
            Text(verbatim: value)
                .foregroundStyle(.secondary)
        case .ddr:
            Text(verbatim: value)
                .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
        }
    }

    @ViewBuilder
    func styledValue(_ change: ImportSummaryChange) -> some View {
        switch change.style {
        case .iidxClearType:
            IIDXMetallicText.clearType(change.current, label: IIDXClearType.abbreviation(for: change.current))
        case .iidxDJLevel:
            IIDXMetallicText.djLevel(change.current)
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
        case .sdvx, .polarisChord, .gitadora: return value.formatted(.number)
        case .iidx, .ddr: return String(value)
        }
    }
}
