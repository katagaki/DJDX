import SwiftUI

struct SDVXScoreRow<Accessory: View>: View {

    var namespace: Namespace.ID

    var record: SDVXSongRecord
    var accessory: Accessory

    init(namespace: Namespace.ID, record: SDVXSongRecord, @ViewBuilder accessory: () -> Accessory) {
        self.namespace = namespace
        self.record = record
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8.0) {
            // Leading clear-mark lamp
            record.clearTypeEnum.color
                .frame(width: 10.0)
                .frame(maxHeight: .infinity)
                .conditionalShadow(.black.opacity(0.2), radius: 1.0, x: 2.0)

            VStack(alignment: .leading, spacing: 2.0) {
                Text(record.title)
                    .bold()
                    .squashedHorizontally()
                HStack(alignment: .center, spacing: 6.0) {
                    if record.gradeEnum != .none && record.gradeEnum != .unknown {
                        Text(verbatim: record.grade)
                            .fontWidth(.expanded)
                            .fontWeight(.black)
                            .sdvxGradeText()
                    }
                    if record.highScore > 0 {
                        Divider().frame(maxHeight: 14.0)
                        Text(String(record.highScore))
                            .font(.scoreline(.caption))
                            .fontWidth(.standard)
                            .sdvxScoreText()
                    }
                    Divider().frame(maxHeight: 14.0)
                    Text(verbatim: record.clearTypeEnum.abbreviation)
                        .foregroundStyle(record.clearTypeEnum.color)
                        .fontWidth(.expanded)
                        .fontWeight(.bold)
                }
                .font(.caption)
                accessory
                    .font(.caption)
            }
            .padding([.top, .bottom], 8.0)
            .matchedTransitionSource(id: "\(record.title).\(record.difficulty)", in: namespace)

            Spacer(minLength: 0.0)

            // Difficulty + level label
            LevelBadge(name: record.difficultyEnum.rawValue, level: record.level,
                       tint: record.difficultyEnum.color, layout: .horizontal)
                .padding([.top, .bottom], 8.0)
        }
        .frame(maxWidth: .infinity)
        .padding(.trailing)
    }
}

extension SDVXScoreRow where Accessory == EmptyView {
    init(namespace: Namespace.ID, record: SDVXSongRecord) {
        self.init(namespace: namespace, record: record) { EmptyView() }
    }
}
