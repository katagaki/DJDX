import SwiftUI

enum FullComboRainbow {
    static let period: TimeInterval = 3.0

    static func color(phase: Double) -> Color {
        Color(hue: phase, saturation: 0.6, brightness: 1.0)
    }
}

struct FullComboRainbowTimeline<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var isActive: Bool
    @ViewBuilder var content: (Double) -> Content

    init(isActive: Bool = true, @ViewBuilder content: @escaping (Double) -> Content) {
        self.isActive = isActive
        self.content = content
    }

    var body: some View {
        if isActive && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                content(
                    context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: FullComboRainbow.period) / FullComboRainbow.period
                )
            }
        } else {
            content(0.0)
        }
    }
}

struct FullComboRainbowFill: View {
    var body: some View {
        FullComboRainbowTimeline { phase in
            Rectangle()
                .fill(FullComboRainbow.color(phase: phase))
        }
    }
}
