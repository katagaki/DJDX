import SwiftUI

struct PlaylineBadge: View {
    let text: String
    var color: Color = .white
    var size: CGFloat = 11.0

    var body: some View {
        Text(verbatim: text)
            .font(.playline(size: size))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, size * 0.8)
            .frame(minHeight: size * 2.5)
            .badgeSurface(cornerRadius: size >= 13.0 ? 6.0 : 4.0)
    }
}

extension View {
    func badgeSurface(cornerRadius: CGFloat, fill: Color? = nil) -> some View {
        background {
            if let fill {
                fill
            } else {
                LinearGradient(colors: [Color(hex: 0x2A2D33), Color(hex: 0x111215)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(.white.opacity(0.25), lineWidth: 1.0)
        }
    }
}

struct IIDXVersionBadge: View {
    let version: IIDXVersion
    var size: CGFloat = 11.0

    var body: some View {
        PlaylineBadge(text: version.marketingName, color: Color(uiColor: version.darkModeColor), size: size)
    }
}

struct IIDXPlayTypeBadge: View {
    let playType: IIDXPlayType
    var size: CGFloat = 11.0

    var body: some View {
        PlaylineBadge(text: playType.displayName(), size: size)
    }
}
