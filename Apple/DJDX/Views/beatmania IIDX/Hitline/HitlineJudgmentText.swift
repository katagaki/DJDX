import SwiftUI

struct HitlineJudgmentStyle {
    let edge: Color
    let glow: Color
    let fill: LinearGradient

    private static func rising(_ stops: Gradient.Stop...) -> LinearGradient {
        LinearGradient(stops: stops, startPoint: .bottom, endPoint: .top)
    }

    private static func falling(_ stops: Gradient.Stop...) -> LinearGradient {
        LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    static func rainbow(hue: Double) -> HitlineJudgmentStyle {
        HitlineJudgmentStyle(
            edge: Color(hue: hue, saturation: 0.79, brightness: 0.48),
            glow: Color(hue: hue, saturation: 0.70, brightness: 1, opacity: 0.53),
            fill: rising(
                .init(color: Color(hex: 0xFFFFFF), location: 0),
                .init(color: Color(hex: 0xFFFFFF), location: 0.30),
                .init(color: Color(hue: hue, saturation: 0.28, brightness: 1), location: 0.52),
                .init(color: Color(hue: hue, saturation: 0.64, brightness: 0.85), location: 1)
            )
        )
    }

    static let great = HitlineJudgmentStyle(
        edge: Color(hex: 0xB34700),
        glow: Color(hex: 0xFFB000, alpha: 0x88),
        fill: rising(
            .init(color: Color(hex: 0xFFFDE8), location: 0),
            .init(color: Color(hex: 0xFFFDE8), location: 0.28),
            .init(color: Color(hex: 0xFFE14D), location: 0.55),
            .init(color: Color(hex: 0xFF9500), location: 1)
        )
    )

    static let good = HitlineJudgmentStyle(
        edge: Color(hex: 0xB34700),
        glow: Color(hex: 0xFF9500, alpha: 0x66),
        fill: rising(
            .init(color: Color(hex: 0xFFF4C2), location: 0),
            .init(color: Color(hex: 0xFFF4C2), location: 0.25),
            .init(color: Color(hex: 0xFFC21A), location: 0.60),
            .init(color: Color(hex: 0xE06A00), location: 1)
        )
    )

    static let bad = HitlineJudgmentStyle(
        edge: Color(hex: 0x6E0000),
        glow: Color(hex: 0xFF3000, alpha: 0x66),
        fill: falling(
            .init(color: Color(hex: 0xF06A0A), location: 0),
            .init(color: Color(hex: 0xFF9A1A), location: 0.45),
            .init(color: Color(hex: 0xFFD23A), location: 0.80),
            .init(color: Color(hex: 0xFFF07A), location: 1)
        )
    )

    static let poor = HitlineJudgmentStyle(
        edge: Color(hex: 0x6E0000),
        glow: Color(hex: 0xFF3000, alpha: 0x66),
        fill: falling(
            .init(color: Color(hex: 0xD81A0A), location: 0),
            .init(color: Color(hex: 0xF04410), location: 0.40),
            .init(color: Color(hex: 0xFF7A18), location: 0.75),
            .init(color: Color(hex: 0xFFA030), location: 1)
        )
    )
}

struct HitlineJudgmentText: View {
    let text: String
    let size: CGFloat
    let style: HitlineJudgmentStyle
    var outlineScale: CGFloat = 1

    private static let ring = LinearGradient(
        colors: [Color(hex: 0x6E6E6E), Color(hex: 0x242424)],
        startPoint: .top,
        endPoint: .bottom
    )

    private func stroke(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width * outlineScale, lineCap: .butt, lineJoin: .miter, miterLimit: 4)
    }

    var body: some View {
        let outline = HitlineOutline(text: text, size: size)
        ZStack {
            outline.fill(.black)
            outline.stroke(.black, style: stroke(6))
            outline.fill(Self.ring)
            outline.stroke(Self.ring, style: stroke(4))
            outline.fill(style.fill)
            outline.stroke(style.edge, style: stroke(2))
        }
        .frame(width: outline.width, height: size)
        .compositingGroup()
        .shadow(color: style.edge, radius: outlineScale)
        .shadow(color: style.glow, radius: 10 * outlineScale)
    }
}

struct HitlineRainbowText: View {
    let text: String
    let size: CGFloat
    var outlineScale: CGFloat = 1
    var period: TimeInterval = 0.5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            HitlineJudgmentText(text: text, size: size, style: .rainbow(hue: 0.5), outlineScale: outlineScale)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let hue = elapsed.truncatingRemainder(dividingBy: period) / period
                HitlineJudgmentText(text: text, size: size, style: .rainbow(hue: hue), outlineScale: outlineScale)
            }
        }
    }
}
