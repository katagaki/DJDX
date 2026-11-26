import SwiftUI

struct AnalyticsGoalTitle: View {
    let goal: AnalyticsGoal

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6.0) {
            switch goal.kind {
            case .rating:
                Text(verbatim: goal.title)
                    .fontWeight(.black)
                    .fontWidth(.expanded)
            case .clearCount, .gradeCount:
                if goal.level > 0 {
                    LevelNumberBadge(level: String(goal.level))
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 5.0 }
                } else {
                    Text("Goals.Level.All")
                        .fontWeight(.black)
                        .fontWidth(.expanded)
                }
                Divider()
                    .frame(maxHeight: 12.0)
                threshold
            }
            if let subtitle = goal.subtitle {
                Text(verbatim: subtitle)
                    .font(.caption2.weight(.semibold))
                    .fontWidth(.expanded)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
    }

    @ViewBuilder
    var threshold: some View {
        let display = AnalyticsGoal.thresholdDisplay(goal.threshold, kind: goal.kind, game: goal.game)
        switch (goal.kind, goal.game) {
        case (.clearCount, .iidxArcade), (.clearCount, .iidxInfinitas):
            IIDXMetallicText.clearType(goal.threshold)
        case (.gradeCount, .iidxArcade), (.gradeCount, .iidxInfinitas):
            IIDXMetallicText.djLevel(goal.threshold)
        case (.gradeCount, .soundVoltex):
            Text(verbatim: display)
                .fontWeight(.black)
                .fontWidth(.expanded)
                .sdvxGradeText()
        case (.clearCount, .soundVoltex):
            Text(verbatim: SDVXClearType(rawValue: goal.threshold)?.abbreviation ?? display)
                .fontWeight(.bold)
                .fontWidth(.expanded)
                .foregroundStyle(SDVXClearType(rawValue: goal.threshold)?.color ?? .primary)
        case (.gradeCount, .danceDanceRevolution):
            Text(verbatim: display)
                .fontWeight(.black)
                .fontWidth(.expanded)
                .foregroundStyle(DDRSongRecord.rankColor(forStem: goal.threshold))
        case (.clearCount, .danceDanceRevolution):
            Text(verbatim: display)
                .fontWeight(.heavy)
                .fontWidth(.expanded)
                .foregroundStyle(DDRSongRecord.clearColor(for: goal.threshold))
        default:
            Text(verbatim: display)
                .fontWeight(.bold)
                .fontWidth(.expanded)
        }
    }
}

extension View {
    func goalNumberFont(size: CGFloat) -> some View {
        font(.scoreline(size: size))
            .fontWidth(.standard)
    }
}
