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
}
