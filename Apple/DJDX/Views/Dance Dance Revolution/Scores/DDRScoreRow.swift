import SwiftUI

struct DDRScoreRow<Accessory: View>: View {

    var record: DDRSongRecord
    var accessory: Accessory
    var verticalPadding: CGFloat = 8.0

    init(record: DDRSongRecord, @ViewBuilder accessory: () -> Accessory) {
        self.record = record
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8.0) {
            DDRSongRecord.clearColor(for: record.clearKind)
                .frame(width: 10.0)
                .frame(maxHeight: .infinity)
                .conditionalShadow(.black.opacity(0.2), radius: 1.0, x: 2.0)

            VStack(alignment: .leading, spacing: 2.0) {
                Text(record.title)
                    .bold()
                    .squashedHorizontally()
                HStack(alignment: .center, spacing: 6.0) {
                    if record.score > 0 {
                        Text(String(record.score))
                            .foregroundStyle(LinearGradient(colors: [.cyan, .blue],
                                                            startPoint: .top, endPoint: .bottom))
                            .font(.scoreline(.caption))
                            .fontWidth(.standard)
                            .fixedSize()
                    }
                    if !record.rankDisplay.isEmpty {
                        Divider().frame(maxHeight: 14.0)
                        Text(record.rankDisplay)
                            .foregroundStyle(DDRSongRecord.rankColor(forStem: record.rank))
                            .fontWidth(.expanded)
                            .fontWeight(.black)
                            .fixedSize()
                    }
                    if !record.clearDisplay.isEmpty {
                        Divider().frame(maxHeight: 14.0)
                        Text(record.clearDisplay)
                            .foregroundStyle(DDRSongRecord.clearColor(for: record.clearKind))
                            .fontWidth(.expanded)
                            .fontWeight(.bold)
                            .fixedSize()
                    }
                }
                .font(.caption)
                accessory
                    .font(.caption)
            }
            .padding([.top, .bottom], verticalPadding)

            Spacer(minLength: 0.0)

            LevelBadge(name: record.difficultyEnum.rawValue,
                       level: record.level > 0 ? String(record.level) : "",
                       tint: record.difficultyEnum.color, layout: .horizontal)
                .padding([.top, .bottom], verticalPadding)
        }
        .frame(maxWidth: .infinity)
        .padding(.trailing)
    }
}

extension DDRScoreRow where Accessory == EmptyView {
    init(record: DDRSongRecord) {
        self.init(record: record) { EmptyView() }
    }
}
