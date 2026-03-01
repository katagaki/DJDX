//
//  WidgetRadarChartView.swift
//  Widgets
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import SwiftUI

struct WidgetRadarChartView: View {
    let data: WidgetRadarData
    var showLabels: Bool = false
    var labelFontSize: CGFloat = 8

    private var points: [RadarPointConfig] {
        [
            RadarPointConfig(
                label: "NOTES", angle: -.pi / 2,
                color: .init(red: 1.0, green: 64 / 255, blue: 235 / 255),
                value: data.notes, alignment: .bottom
            ),
            RadarPointConfig(
                label: "CHORD", angle: 7 * .pi / 6,
                color: .init(red: 133 / 255, green: 225 / 255, blue: 0 / 255),
                value: data.chord, alignment: .bottomTrailing
            ),
            RadarPointConfig(
                label: "CHARGE", angle: 5 * .pi / 6,
                color: .init(red: 137 / 255, green: 87 / 255, blue: 221 / 255),
                value: data.charge, alignment: .topTrailing
            ),
            RadarPointConfig(
                label: "SOF-LAN", angle: .pi / 2,
                color: .init(red: 0 / 255, green: 134 / 255, blue: 229 / 255),
                value: data.soflan, alignment: .top
            ),
            RadarPointConfig(
                label: "SCRATCH", angle: .pi / 6,
                color: .init(red: 221 / 255, green: 0 / 255, blue: 0 / 255),
                value: data.scratch, alignment: .topLeading
            ),
            RadarPointConfig(
                label: "PEAK", angle: -.pi / 6,
                color: .init(red: 1.0, green: 108 / 255, blue: 0 / 255),
                value: data.peak, alignment: .bottomLeading
            )
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
            let padding: CGFloat = showLabels ? 30.0 : 12.0
            let size = min(geometry.size.width - padding, geometry.size.height - padding)
            let circleScale = benchmarkValue / maxValue
            let circleSize = size * CGFloat(circleScale)

            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    .frame(width: circleSize, height: circleSize)

                RadarAxesShape(configs: points)
                    .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [3]))
                    .frame(width: size, height: size)

                RadarPolygonShape(configs: points, maxValue: maxValue)
                    .fill(color.opacity(0.5))
                    .frame(width: size, height: size)

                RadarPolygonShape(configs: points, maxValue: maxValue)
                    .stroke(color, lineWidth: 1.5)
                    .frame(width: size, height: size)

                if showLabels {
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    let radius = size / 2

                    ForEach(0..<points.count, id: \.self) { index in
                        let config = points[index]
                        let tipX = center.x + radius * CGFloat(cos(config.angle))
                        let tipY = center.y + radius * CGFloat(sin(config.angle))

                        Color.clear
                            .frame(width: 0, height: 0)
                            .overlay(
                                Text(config.label)
                                    .font(.system(size: labelFontSize, weight: .black))
                                    .fontWidth(.expanded)
                                    .foregroundStyle(config.color)
                                    .fixedSize(),
                                alignment: config.alignment
                            )
                            .position(x: tipX, y: tipY)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}
