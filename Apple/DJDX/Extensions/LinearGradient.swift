import SwiftUI

extension LinearGradient {
    static func metallic(highlight: Color, base: Color, shade: Color) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: highlight, location: 0.0),
                .init(color: highlight, location: 0.2),
                .init(color: base, location: 0.48),
                .init(color: shade, location: 0.52),
                .init(color: base, location: 0.85),
                .init(color: highlight, location: 1.0)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    static let iidxScore = LinearGradient.metallic(
        highlight: Color(red: 0.72, green: 0.93, blue: 1.0),
        base: Color(red: 0.4, green: 0.82, blue: 0.98),
        shade: Color(red: 0.28, green: 0.72, blue: 0.95)
    )
}
