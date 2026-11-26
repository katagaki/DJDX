import SwiftUI

struct ShareCardView: View {

    let game: Game
    let profile: ShareCardProfile?
    let entries: [ShareCardEntry]
    let totalCount: Int
    var playStyle: String?
    let background: ShareCardBackground
    let photo: UIImage?
    let accentColor: Color
    var customColor: Color = .accentColor
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
        VStack(alignment: .leading, spacing: 12.0) {
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
                if let profile, !profile.isEmpty, !profile.hasVisuals {
                    profileText(profile, alignment: .trailing)
                }
                if let playStyle {
                    Text(verbatim: playStyle)
                        .font(.system(size: 13.0, weight: .black))
                        .fontWidth(.expanded)
                        .padding(.horizontal, 10.0)
                        .padding(.vertical, 5.0)
                        .background(.white.opacity(0.2), in: .capsule)
                }
            }
            if let profile, profile.hasVisuals {
                profileBand(profile)
            }
        }
    }

    func profileText(_ profile: ShareCardProfile, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2.0) {
            if let playerName = profile.playerName, !playerName.isEmpty {
                Text(verbatim: playerName)
                    .font(.system(size: 15.0, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            ForEach(profile.ratings) { rating in
                HStack(alignment: .firstTextBaseline, spacing: 4.0) {
                    if !rating.label.isEmpty {
                        Text(verbatim: rating.label)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Text(verbatim: rating.value)
                        .monospacedDigit()
                }
                .font(.system(size: 11.0, weight: .heavy))
                .fontWidth(.condensed)
                .lineLimit(1)
            }
        }
    }

    func profileBand(_ profile: ShareCardProfile) -> some View {
        HStack(alignment: .center, spacing: 12.0) {
            if let avatar = profile.avatar {
                Image(uiImage: avatar)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 110.0)
            }
            profileText(profile, alignment: .leading)
            Spacer(minLength: 0.0)
            if let radar = profile.radar {
                RadarChartView(radar, isPlayerRadar: true, labelFontSize: 8.0, lineWidth: 1.5)
                    .frame(width: 170.0, height: 110.0)
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
        case .custom:
            LinearGradient(
                colors: [customColor, customColor.mix(with: .black, by: 0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
