import SwiftUI

struct RadarLabelStyle: ViewModifier {

    @Environment(\.colorScheme) var colorScheme

    let color: Color

    func body(content: Content) -> some View {
        switch colorScheme {
        case .light:
            content
                .foregroundStyle(color)
                .brightness(-0.18)
                .shadow(color: color.opacity(0.35), radius: 2.0)
        default:
            content
                .foregroundStyle(color)
                .brightness(0.88)
                .shadow(color: color, radius: 1.0)
                .shadow(color: color, radius: 3.0)
        }
    }
}

extension View {
    func radarLabelStyle(_ color: Color) -> some View {
        modifier(RadarLabelStyle(color: color))
    }
}
