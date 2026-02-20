//
//  RadarPolygonShape.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/02/21.
//

import SwiftUI

struct RadarPolygonShape: Shape {
    let configs: [RadarPointConfig]
    let maxValue: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) / 2

        for (index, config) in configs.enumerated() {
            let normalizedValue = min(max(config.value / maxValue, 0), 1)
            let pointRadius = maxRadius * CGFloat(normalizedValue)
            let xPt = center.x + pointRadius * CGFloat(cos(config.angle))
            let yPt = center.y + pointRadius * CGFloat(sin(config.angle))

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
