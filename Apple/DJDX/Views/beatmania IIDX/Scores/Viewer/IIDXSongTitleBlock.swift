import SwiftUI

struct IIDXSongTitleBlock: View {

    @AppStorage(wrappedValue: IIDXVersion.zinrai, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    var genre: String?
    var title: String
    var artist: String?
    var version: String?
    var isLeggendaria: Bool

    private var titleStyle: AnyShapeStyle {
        if isLeggendaria {
            return AnyShapeStyle(IIDXVersion.leggendariaSongTitleTextColor)
        }
        if let version {
            return AnyShapeStyle(iidxVersion.songTitleTextColor(for: version))
        }
        return AnyShapeStyle(.primary)
    }

    private var titleStrokeColor: Color {
        if isLeggendaria {
            return IIDXVersion.leggendariaSongTitleStrokeColor
        }
        if let version {
            return iidxVersion.songTitleStrokeColor(for: version)
        }
        return .clear
    }

    var body: some View {
        VStack(alignment: .center, spacing: 4.0) {
            Group {
                if let genre, !genre.isEmpty {
                    caption(genre)
                }
                Text(verbatim: title)
                    .font(.title)
                    .fontWeight(.heavy)
                    .fontWidth(.compressed)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(titleStyle)
                    .strokeText(color: titleStrokeColor, width: 0.5)
                    .textSelection(.enabled)
                    .padding(.bottom, 2.0)
                if let artist, !artist.isEmpty {
                    caption(artist)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    private func caption(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.subheadline)
            .fontWeight(.heavy)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .strokeText(color: .black.opacity(0.7), width: 0.5)
    }
}
