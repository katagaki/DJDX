import SwiftUI

struct SDVXScoreRow: View {

    var namespace: Namespace.ID

    var record: SDVXSongRecord

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
                    .fontWidth(.condensed)
                    .lineLimit(2)
                HStack(alignment: .center, spacing: 6.0) {
                    if record.gradeEnum != .none && record.gradeEnum != .unknown {
                        Text(verbatim: record.grade)
                            .foregroundStyle(LinearGradient(colors: [.yellow, .orange],
                                                            startPoint: .top, endPoint: .bottom))
                            .fontWidth(.expanded)
                            .fontWeight(.black)
                    }
                    if record.highScore > 0 {
                        Divider().frame(maxHeight: 14.0)
                        Text(String(record.highScore))
                            .foregroundStyle(LinearGradient(colors: [.cyan, .blue],
                                                            startPoint: .top, endPoint: .bottom))
                            .fontWidth(.expanded)
                            .fontWeight(.heavy)
                    }
                    Divider().frame(maxHeight: 14.0)
                    Text(verbatim: record.clearTypeEnum.abbreviation)
                        .foregroundStyle(record.clearTypeEnum.color)
                        .fontWidth(.expanded)
                        .fontWeight(.bold)
                }
                .font(.caption)
            }
            .padding([.top, .bottom], 8.0)
            .automaticMatchedTransitionSource(id: "\(record.title).\(record.difficulty)", in: namespace)

            Spacer(minLength: 0.0)

            // Difficulty + level label
            HStack(alignment: .center, spacing: 4.0) {
                Text(verbatim: record.difficultyEnum.abbreviation)
                    .lineLimit(1)
                Spacer(minLength: 0.0)
                Text(verbatim: record.level)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .font(.system(size: 14.0).weight(.bold))
            .foregroundStyle(.white)
            .padding([.leading, .trailing], 8.0)
            .padding([.top, .bottom], 8.0)
            .frame(width: 92.0)
            .background(record.difficultyEnum.color)
            .clipShape(.rect(cornerRadius: 6.0))
            .padding([.top, .bottom], 8.0)
        }
        .frame(maxWidth: .infinity)
        .padding(.trailing)
    }
}
