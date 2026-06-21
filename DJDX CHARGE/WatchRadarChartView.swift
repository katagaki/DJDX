import SwiftUI

struct WatchRadarData {
    let notes: Double
    let chord: Double
    let peak: Double
    let charge: Double
    let scratch: Double
    let soflan: Double

    init(notes: Double, chord: Double, peak: Double, charge: Double, scratch: Double, soflan: Double) {
        self.notes = notes
        self.chord = chord
        self.peak = peak
        self.charge = charge
        self.scratch = scratch
        self.soflan = soflan
    }

    init?(values: [Double]) {
        guard values.count == 6 else { return nil }
        self.init(
            notes: values[0],
            chord: values[1],
            peak: values[2],
            charge: values[3],
            scratch: values[4],
            soflan: values[5]
        )
    }

    var sum: Double {
        [notes, chord, peak, charge, scratch, soflan].reduce(0, +)
    }
}

struct WatchRadarPoint {
    let label: String
    let angle: Double
    let color: Color
    let value: Double
    let alignment: Alignment
}

struct WatchRadarAxesShape: Shape {
    let points: [WatchRadarPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        for point in points {
            let xPt = center.x + radius * CGFloat(cos(point.angle))
            let yPt = center.y + radius * CGFloat(sin(point.angle))
            path.move(to: center)
            path.addLine(to: CGPoint(x: xPt, y: yPt))
        }
        return path
    }
}

struct WatchRadarPolygonShape: Shape {
    let points: [WatchRadarPoint]
    let maxValue: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) / 2
        for (index, point) in points.enumerated() {
            let normalizedValue = min(max(point.value / maxValue, 0), 1)
            let pointRadius = maxRadius * CGFloat(normalizedValue)
            let xPt = center.x + pointRadius * CGFloat(cos(point.angle))
            let yPt = center.y + pointRadius * CGFloat(sin(point.angle))
            if index == 0 {
                path.move(to: CGPoint(x: xPt, y: yPt))
            } else {
                path.addLine(to: CGPoint(x: xPt, y: yPt))
            }
        }
        path.closeSubpath()
        return path
    }
}

struct WatchRadarTableView: View {
    let data: WatchRadarData

    private static let order = ["NOTES", "CHORD", "PEAK", "CHARGE", "SCRATCH", "SOF-LAN"]
    private static let colors: [String: Color] = [
        "NOTES": .init(red: 1.0, green: 64 / 255, blue: 235 / 255),
        "CHORD": .init(red: 133 / 255, green: 225 / 255, blue: 0 / 255),
        "PEAK": .init(red: 1.0, green: 108 / 255, blue: 0 / 255),
        "CHARGE": .init(red: 137 / 255, green: 87 / 255, blue: 221 / 255),
        "SCRATCH": .init(red: 221 / 255, green: 0 / 255, blue: 0 / 255),
        "SOF-LAN": .init(red: 0 / 255, green: 134 / 255, blue: 229 / 255)
    ]

    private func value(for label: String) -> Double {
        switch label {
        case "NOTES": return data.notes
        case "CHORD": return data.chord
        case "PEAK": return data.peak
        case "CHARGE": return data.charge
        case "SCRATCH": return data.scratch
        case "SOF-LAN": return data.soflan
        default: return 0
        }
    }

    var body: some View {
        VStack(spacing: 3.0) {
            ForEach(Self.order, id: \.self) { label in
                HStack {
                    Text(verbatim: label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Self.colors[label] ?? .primary)
                    Spacer()
                    Text(verbatim: String(format: "%.2f", value(for: label)))
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                }
            }
            Divider()
            HStack {
                Text(verbatim: "TOTAL")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text(verbatim: String(format: "%.2f", data.sum))
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
            }
        }
    }
}

struct WatchRadarChartView: View {
    let data: WatchRadarData
    var showLabels: Bool = true
    var labelFontSize: CGFloat = 9.0

    private var points: [WatchRadarPoint] {
        [
            WatchRadarPoint(label: "NOTES", angle: -.pi / 2,
                            color: .init(red: 1.0, green: 64 / 255, blue: 235 / 255), value: data.notes,
                            alignment: .bottom),
            WatchRadarPoint(label: "CHORD", angle: 7 * .pi / 6,
                            color: .init(red: 133 / 255, green: 225 / 255, blue: 0 / 255), value: data.chord,
                            alignment: .bottomTrailing),
            WatchRadarPoint(label: "CHARGE", angle: 5 * .pi / 6,
                            color: .init(red: 137 / 255, green: 87 / 255, blue: 221 / 255), value: data.charge,
                            alignment: .topTrailing),
            WatchRadarPoint(label: "SOF-LAN", angle: .pi / 2,
                            color: .init(red: 0 / 255, green: 134 / 255, blue: 229 / 255), value: data.soflan,
                            alignment: .top),
            WatchRadarPoint(label: "SCRATCH", angle: .pi / 6,
                            color: .init(red: 221 / 255, green: 0 / 255, blue: 0 / 255), value: data.scratch,
                            alignment: .topLeading),
            WatchRadarPoint(label: "PEAK", angle: -.pi / 6,
                            color: .init(red: 1.0, green: 108 / 255, blue: 0 / 255), value: data.peak,
                            alignment: .bottomLeading)
        ]
    }

    private var color: Color {
        let sum = data.sum
        if sum > 600.0 { return .purple
        } else if sum > 400.0 { return .red
        } else if sum > 200.0 { return .yellow
        } else { return .cyan }
    }

    private let maxValue: Double = 130.0
    private let benchmarkValue: Double = 100.0

    var body: some View {
        GeometryReader { geometry in
            let padding: CGFloat = showLabels ? 52.0 : 8.0
            let size = min(geometry.size.width - padding, geometry.size.height - padding)
            let circleScale = benchmarkValue / maxValue
            let circleSize = size * CGFloat(circleScale)

            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    .frame(width: circleSize, height: circleSize)

                WatchRadarAxesShape(points: points)
                    .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [3]))
                    .frame(width: size, height: size)

                WatchRadarPolygonShape(points: points, maxValue: maxValue)
                    .fill(color.opacity(0.5))
                    .frame(width: size, height: size)

                WatchRadarPolygonShape(points: points, maxValue: maxValue)
                    .stroke(color, lineWidth: 1.5)
                    .frame(width: size, height: size)

                if showLabels {
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    let radius = size / 2
                    ForEach(0..<points.count, id: \.self) { index in
                        let point = points[index]
                        let tipX = center.x + radius * CGFloat(cos(point.angle))
                        let tipY = center.y + radius * CGFloat(sin(point.angle))
                        Color.clear
                            .frame(width: 0, height: 0)
                            .overlay(
                                Text(point.label)
                                    .font(.system(size: labelFontSize, weight: .black))
                                    .fontWidth(.expanded)
                                    .foregroundStyle(point.color)
                                    .fixedSize(),
                                alignment: point.alignment
                            )
                            .position(x: tipX, y: tipY)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}
