import SwiftUI

extension Color {
    static let iidxScore = Color(red: 0.58, green: 0.92, blue: 0.94)
    static let iidxScoreOutline = Color(red: 0.28, green: 0.6, blue: 0.93)
}

extension Color {
    init(hex: UInt32, alpha: UInt8 = 0xFF) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: Double(alpha) / 255
        )
    }
}
