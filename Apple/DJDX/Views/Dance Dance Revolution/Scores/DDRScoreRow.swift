import SwiftUI

struct DDRScoreRow: View {

    var record: DDRSongRecord

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
                    }
                    if !record.rankDisplay.isEmpty {
                        Divider().frame(maxHeight: 14.0)
                        Text(record.rankDisplay)
                            .foregroundStyle(DDRSongRecord.rankColor(forStem: record.rank))
                            .fontWidth(.expanded)
                            .fontWeight(.black)
                    }
                    if !record.clearDisplay.isEmpty {
                        Divider().frame(maxHeight: 14.0)
                        Text(record.clearDisplay)
                            .foregroundStyle(DDRSongRecord.clearColor(for: record.clearKind))
                            .fontWidth(.expanded)
                            .fontWeight(.bold)
                    }
                }
                .font(.caption)
            }
            .padding([.top, .bottom], 8.0)

            Spacer(minLength: 0.0)

            LevelBadge(name: record.difficultyEnum.rawValue,
                       level: record.level > 0 ? String(record.level) : "",
                       tint: record.difficultyEnum.color, layout: .horizontal)
                .padding([.top, .bottom], 8.0)
        }
        .frame(maxWidth: .infinity)
        .padding(.trailing)
    }
}
