import SwiftUI

private let radarLayout: [(index: Int, angle: Double)] = [
    (0, -.pi / 2),     // NOTES (top)
    (1, 7 * .pi / 6),  // CHORD
    (3, 5 * .pi / 6),  // CHARGE
    (5, .pi / 2),      // SOF-LAN (bottom)
    (4, .pi / 6),      // SCRATCH
    (2, -.pi / 6)      // PEAK
]

private let radarSpokeColors: [Color] = [
    .init(red: 1.0, green: 64 / 255, blue: 235 / 255),      // NOTES
    .init(red: 133 / 255, green: 225 / 255, blue: 0 / 255), // CHORD
    .init(red: 1.0, green: 108 / 255, blue: 0 / 255),       // PEAK
    .init(red: 137 / 255, green: 87 / 255, blue: 221 / 255), // CHARGE
    .init(red: 221 / 255, green: 0 / 255, blue: 0 / 255),   // SCRATCH
    .init(red: 0 / 255, green: 134 / 255, blue: 229 / 255)  // SOF-LAN
]

struct ComplicationRadarShape: Shape {
    let values: [Double]
    let maxValue: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) / 2
        for (offset, entry) in radarLayout.enumerated() {
            let value = entry.index < values.count ? values[entry.index] : 0
            let radius = maxRadius * CGFloat(min(max(value / maxValue, 0), 1))
            let point = CGPoint(
                x: center.x + radius * CGFloat(cos(entry.angle)),
                y: center.y + radius * CGFloat(sin(entry.angle))
            )
            if offset == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct ComplicationRadarAxes: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        for entry in radarLayout {
            path.move(to: center)
            path.addLine(to: CGPoint(
                x: center.x + radius * CGFloat(cos(entry.angle)),
                y: center.y + radius * CGFloat(sin(entry.angle))
            ))
        }
        return path
    }
}

struct ComplicationRadarView: View {
    let values: [Double]
    private let maxValue: Double = 130.0
    private let benchmarkValue: Double = 100.0

    private var color: Color {
        let highest = radarLayout
            .map { (index: $0.index, value: $0.index < values.count ? values[$0.index] : 0) }
            .max { $0.value < $1.value }
        guard let highest else { return .cyan }
        return radarSpokeColors[highest.index]
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let circleSize = size * CGFloat(benchmarkValue / maxValue)
            ZStack {
                Circle()
                    .fill(.gray.opacity(0.3))
                    .stroke(.gray.opacity(0.5), lineWidth: 0.5)
                    .frame(width: circleSize, height: circleSize)
                ComplicationRadarAxes()
                    .stroke(.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 0.5, dash: [2]))
                ComplicationRadarShape(values: values, maxValue: maxValue)
                    .fill(color.opacity(0.4))
                ComplicationRadarShape(values: values, maxValue: maxValue)
                    .stroke(color, lineWidth: 1.5)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding(2.0)
    }
}
