import SwiftUI

struct ShareCardView: View {

    let game: Game
    let profile: ShareCardProfile?
    let entries: [ShareCardEntry]
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
            if !entries.isEmpty {
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
            }
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
                        .font(.playline(size: 15.0))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(verbatim: date.formatted(.verbatim(
                        "\(year: .defaultDigits)/\(month: .twoDigits)/\(day: .twoDigits)",
                        timeZone: .current, calendar: Calendar(identifier: .gregorian))))
                        .font(.playline(size: 11.0, weight: .regular))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer(minLength: 8.0)
                if let profile, !profile.isEmpty, !profile.hasVisuals {
                    profileText(profile, alignment: .trailing)
                }
                if let playStyle {
                    Text(verbatim: playStyle)
                        .font(.playline(size: 13.0))
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
                    .font(.playline(size: 16.0))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            ForEach(profile.ratings) { rating in
                HStack(alignment: .firstTextBaseline, spacing: 4.0) {
                    if !rating.label.isEmpty {
                        Text(verbatim: rating.label)
                            .font(.playline(size: 11.0, weight: .regular))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Text(verbatim: rating.value)
                        .font(rating.value.first?.isNumber == true ? .scoreline(size: 13.0) : .playline(size: 13.0))
                }
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
            Spacer()
            Text(verbatim: "DJDX")
        }
        .font(.playline(size: 11.0))
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
                if let titleStrokeColor = entry.titleStrokeColor {
                    Text(verbatim: entry.title)
                        .font(.system(size: 15.0, weight: .heavy))
                        .fontWidth(.compressed)
                        .foregroundStyle(entry.titleStyle)
                        .strokeText(color: titleStrokeColor, width: 0.35)
                        .shareCardSquashed()
                } else {
                    Text(verbatim: entry.title)
                        .font(.system(size: 14.0, weight: .bold))
                        .foregroundStyle(entry.titleStyle)
                        .shareCardSquashed()
                }
                if let subtitle = entry.subtitle, !subtitle.isEmpty {
                    Text(verbatim: subtitle)
                        .font(.system(size: 11.0, weight: .heavy))
                        .foregroundStyle(.white)
                        .strokeText(color: .black.opacity(0.7), width: 0.35)
                        .shareCardSquashed()
                }
                if !entry.metrics.isEmpty {
                    HStack(spacing: 8.0) {
                        ForEach(entry.metrics) { metric in
                            ShareCardMetricText(metric: metric)
                        }
                    }
                    .lineLimit(1)
                }
            }
            .padding(.vertical, 8.0)
            Spacer(minLength: 0.0)
            LevelBadge(name: entry.difficultyText, level: entry.levelText,
                       tint: entry.difficultyColor, layout: .horizontal)
                .padding(.vertical, 8.0)
        }
        .padding(.trailing, 6.0)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ShareCardMetricText: View {

    let metric: ShareCardMetric

    var body: some View {
        switch metric.typeface {
        case .score:
            Text(verbatim: metric.text)
                .font(.scoreline(size: 11.0))
                .foregroundStyle(metric.style)
        case .grade:
            Text(verbatim: metric.text)
                .font(.system(size: 11.0, weight: .black))
                .fontWidth(.expanded)
                .foregroundStyle(metric.style)
        case .clearType:
            Text(verbatim: metric.text)
                .font(.playline(size: 11.0, weight: .regular))
                .foregroundStyle(metric.style)
        }
    }
}

private extension View {
    func shareCardSquashed() -> some View {
        self
            .lineLimit(1)
            .fixedSize()
            .visualEffect { content, proxy in
                let availableWidth = proxy.bounds(of: .named("ShareCardSquash"))?.width ?? proxy.size.width
                let scale = proxy.size.width > availableWidth ? availableWidth / proxy.size.width : 1.0
                return content.scaleEffect(x: scale, y: 1.0, anchor: .leading)
            }
            .frame(minWidth: 0.0, maxWidth: .infinity, alignment: .leading)
            .coordinateSpace(.named("ShareCardSquash"))
    }
}
