import SwiftUI

enum FullComboRainbow {
    static let period: TimeInterval = 3.0

    static func gradient(phase: Double) -> LinearGradient {
        let count = 6
        let stops = (0...count).map { index in
            let location = Double(index) / Double(count)
            let hue = (location - phase + 1.0).truncatingRemainder(dividingBy: 1.0)
            return Gradient.Stop(
                color: Color(hue: hue, saturation: 0.6, brightness: 1.0),
                location: location
            )
        }
        return LinearGradient(stops: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
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
                .fill(FullComboRainbow.gradient(phase: phase))
        }
    }
}
