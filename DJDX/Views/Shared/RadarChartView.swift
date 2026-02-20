//
//  RadarChartView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/02/21.
//

import SwiftUI

struct RadarChartView: View {
    let color: Color
    let points: [RadarPointConfig]
    let maxValue: Double = 130.0
    let benchmarkValue: Double = 100.0

    init(_ data: RadarData) {
        self.color = data.color()
        self.points = data.points()
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width - 30.0, geometry.size.height - 30.0)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = size / 2
            let circleScale = benchmarkValue / maxValue
            let circleSize = size * CGFloat(circleScale)

            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .stroke(Color.gray.opacity(0.8), lineWidth: 2)
                    .frame(width: circleSize, height: circleSize)

                RadarAxesShape(configs: points)
                    .stroke(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .frame(width: size, height: size)

                ZStack {
                    RadarPolygonShape(configs: points, maxValue: maxValue)
                        .fill(color.opacity(0.5))
                    RadarPolygonShape(configs: points, maxValue: maxValue)
                        .stroke(color, lineWidth: 2)
                }
                .frame(width: size, height: size)

                ForEach(0..<points.count, id: \.self) { index in
                    let config = points[index]
                    let tipX = center.x + radius * CGFloat(cos(config.angle))
                    let tipY = center.y + radius * CGFloat(sin(config.angle))

                    Color.clear
                        .frame(width: 0, height: 0)
                        .overlay(
                            Text(config.label)
                                .font(.system(size: 12, weight: .black))
                                .fontWidth(.expanded)
                                .foregroundStyle(config.color)
                                .brightness(0.88)
                                .shadow(color: config.color, radius: 1.0)
                                .shadow(color: config.color, radius: 3.0)
                                .fixedSize(),
                            alignment: config.alignment
                        )
                        .position(x: tipX, y: tipY)
                }
            }
        }
    }
}
