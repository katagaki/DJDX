//
//  RadarAxesShape.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/02/21.
//

import SwiftUI

struct RadarAxesShape: Shape {
    let configs: [RadarPointConfig]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        for config in configs {
            let xPt = center.x + radius * CGFloat(cos(config.angle))
            let yPt = center.y + radius * CGFloat(sin(config.angle))
            path.move(to: center)
            path.addLine(to: CGPoint(x: xPt, y: yPt))
        }
        return path
    }
}
