import SwiftUI

struct ShareCardView: View {

    let game: Game
    let profile: ShareCardProfile?
    let entries: [ShareCardEntry]
    let totalCount: Int
    let background: ShareCardBackground
    let photo: UIImage?
    let accentColor: Color
    var date: Date = .now

    static let width: CGFloat = 390.0

    var body: some View {
        VStack(alignment: .leading, spacing: 14.0) {
            header
            VStack(spacing: 0.0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 {
                        Rectangle()
                            .fill(.white.opacity(0.12))
                            .frame(height: 0.5)
                            .padding(.leading, 18.0)
                    }
                    ShareCardRow(entry: entry)
                }
            }
            .background(.black.opacity(0.4))
            .clipShape(.rect(cornerRadius: 14.0))
            footer
        }
        .padding(20.0)
        .frame(width: Self.width)
        .background {
            backgroundView
        }
        .clipped()
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder var header: some View {
        HStack(alignment: .center, spacing: 10.0) {
            if let iconResource = game.iconResource {
                Image(iconResource)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36.0, height: 36.0)
                    .clipShape(.rect(cornerRadius: 8.0))
            }
            VStack(alignment: .leading, spacing: 1.0) {
                Text(verbatim: game.displayName)
                    .font(.system(size: 15.0, weight: .heavy))
                    .fontWidth(.expanded)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(date, format: .dateTime.year().month().day())
                    .font(.system(size: 11.0, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 8.0)
            if let profile, !profile.isEmpty {
                VStack(alignment: .trailing, spacing: 2.0) {
                    if let playerName = profile.playerName, !playerName.isEmpty {
                        Text(verbatim: playerName)
                            .font(.system(size: 15.0, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    ForEach(profile.ratings) { rating in
                        HStack(spacing: 4.0) {
                            Text(verbatim: rating.label)
                                .foregroundStyle(.white.opacity(0.7))
                            Text(verbatim: rating.value)
                                .monospacedDigit()
                        }
                        .font(.system(size: 11.0, weight: .heavy))
                        .fontWidth(.condensed)
                        .lineLimit(1)
                    }
                }
            }
        }
    }

    @ViewBuilder var footer: some View {
        HStack {
            if totalCount > entries.count {
                Text("ShareCard.More.\(totalCount - entries.count)")
            }
            Spacer()
            Text(verbatim: "DJDX")
                .fontWidth(.expanded)
        }
        .font(.system(size: 11.0, weight: .heavy))
        .foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, 4.0)
    }

    @ViewBuilder var backgroundView: some View {
        switch background {
        case .gradient(let gradient):
            LinearGradient(
                colors: gradient.colors(accentColor: accentColor),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .appIcon(let imageName):
            ZStack {
                Color.black
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 24.0)
                    .saturation(1.3)
                Color.black.opacity(0.2)
            }
        case .photo:
            ZStack {
                Color.black
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                }
                Color.black.opacity(0.35)
            }
        }
    }
}

struct ShareCardRow: View {

    let entry: ShareCardEntry

    var body: some View {
        HStack(alignment: .center, spacing: 10.0) {
            Rectangle()
                .fill(entry.lampStyle)
                .frame(width: 8.0)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 2.0) {
                Text(verbatim: entry.title)
                    .font(.system(size: 14.0, weight: .bold))
                    .lineLimit(1)
                if let subtitle = entry.subtitle, !subtitle.isEmpty {
                    Text(verbatim: subtitle)
                        .font(.system(size: 11.0, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
                if !entry.metrics.isEmpty {
                    HStack(spacing: 8.0) {
                        ForEach(entry.metrics) { metric in
                            Text(verbatim: metric.text)
                                .foregroundStyle(metric.style)
                        }
                    }
                    .font(.system(size: 11.0, weight: .heavy))
                    .fontWidth(.expanded)
                    .monospacedDigit()
                    .lineLimit(1)
                }
            }
            .padding(.vertical, 8.0)
            Spacer(minLength: 0.0)
            VStack(spacing: 0.0) {
                Text(verbatim: entry.levelText)
                    .font(.system(size: 17.0, weight: .black))
                    .italic()
                    .monospacedDigit()
                Text(verbatim: entry.difficultyText)
                    .font(.system(size: 9.0, weight: .heavy))
                    .fontWidth(.condensed)
                    .foregroundStyle(entry.difficultyColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(width: 60.0)
            .padding(.vertical, 8.0)
        }
        .padding(.trailing, 6.0)
        .fixedSize(horizontal: false, vertical: true)
    }
}
