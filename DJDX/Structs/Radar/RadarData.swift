//
//  RadarData.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/02/21.
//

import SwiftUI

struct RadarData {
    let notes: Double
    let chord: Double
    let peak: Double
    let charge: Double
    let scratch: Double
    let soflan: Double

    func points() -> [RadarPointConfig] {
        return [
            RadarPointConfig(
                label: "NOTES",
                angle: -.pi / 2,
                color: .init(red: 255 / 255, green: 64 / 255, blue: 235 / 255),
                value: self.notes,
                alignment: .bottom
            ),
            RadarPointConfig(
                label: "CHORD",
                angle: 7 * .pi / 6,
                color: .init(red: 133 / 255, green: 225 / 255, blue: 0 / 255),
                value: self.chord,
                alignment: .bottomTrailing
            ),
            RadarPointConfig(
                label: "CHARGE",
                angle: 5 * .pi / 6,
                color: .init(red: 137 / 255, green: 87 / 255, blue: 221 / 255),
                value: self.charge,
                alignment: .topTrailing
            ),
            RadarPointConfig(
                label: "SOF-LAN",
                angle: .pi / 2,
                color: .init(red: 0 / 255, green: 134 / 255, blue: 229 / 255),
                value: self.soflan,
                alignment: .top
            ),
            RadarPointConfig(
                label: "SCRATCH",
                angle: .pi / 6,
                color: .init(red: 221 / 255, green: 0 / 255, blue: 0 / 255),
                value: self.scratch,
                alignment: .topLeading
            ),
            RadarPointConfig(
                label: "PEAK",
                angle: -.pi / 6,
                color: .init(red: 255 / 255, green: 108 / 255, blue: 0 / 255),
                value: self.peak,
                alignment: .bottomLeading
            )
        ]
    }

    func sum() -> Double {
        return [self.notes, self.peak, self.scratch, self.soflan, self.charge, self.chord].reduce(0, +)
    }

    func color() -> Color {
        let sum = self.sum()
        if sum > 600.0 {
            return .purple
        } else if sum > 400.0 {
            return .red
        } else if sum > 200.0 {
            return .yellow
        } else {
            return .cyan
        }
    }
}
