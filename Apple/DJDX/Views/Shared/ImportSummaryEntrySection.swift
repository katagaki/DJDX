import SwiftUI

struct ImportSummaryEntrySection: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    let entry: ImportSummaryEntry
    let game: ImportSummaryGame

    var body: some View {
        Section {
            header()
            details()
        }
    }

    @ViewBuilder
    func header() -> some View {
        HStack(alignment: .center, spacing: 8.0) {
            Text(verbatim: entry.title)
                .font(.title3)
                .fontWeight(.heavy)
                .fontWidth(.compressed)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Spacer(minLength: 0.0)
            VStack(spacing: 1.0) {
                Text(verbatim: entry.level)
                    .font(.system(size: 18.0).weight(.heavy))
                    .fontWidth(.condensed)
                    .monospacedDigit()
                Text(verbatim: entry.difficulty)
                    .font(.system(size: 10.0).weight(.black))
                    .fontWidth(.condensed)
                    .foregroundStyle(entry.difficultyColor)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.vertical, 6.0)
            .frame(width: 78.0, alignment: .center)
            .cardBackground(cornerRadius: 6.0)
        }
    }

    @ViewBuilder
    func details() -> some View {
        VStack(alignment: .leading, spacing: 8.0) {
            if let score = entry.score {
                detailRow("SCORE") {
                    VStack(alignment: .trailing, spacing: 2.0) {
                        scoreText(scoreString(score))
                            .font(.subheadline)
                        if let previousScore = entry.previousScore {
                            Text(verbatim: "+" + scoreString(score - previousScore))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if let lamp = entry.lamp {
                detailRow("CLEAR TYPE") {
                    styledValue(lamp)
                }
            }
            if let grade = entry.grade {
                detailRow(game.gradeTitle) {
                    styledValue(grade)
                }
            }
        }
    }

    @ViewBuilder
    func detailRow(
        _ title: String, @ViewBuilder current: () -> some View
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6.0) {
            Text(verbatim: title)
            Spacer(minLength: 8.0)
            HStack(spacing: 6.0) {
                current()
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .font(.caption)
        .fontWidth(.expanded)
        .fontWeight(.heavy)
        .monospacedDigit()
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
                .fontWidth(.expanded)
                .fontWeight(.heavy)
        case .polarisChord, .ddr:
            Text(verbatim: value)
                .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
        }
    }

    @ViewBuilder
    func styledValue(_ change: ImportSummaryChange) -> some View {
        switch change.style {
        case .iidxClearType:
            IIDXMetallicText.clearType(change.current)
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
        case .sdvx, .polarisChord: return value.formatted(.number)
        case .iidx, .ddr: return String(value)
        }
    }
}
