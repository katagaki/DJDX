//
//  IIDXDJLevel.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/02.
//

import SwiftUI

enum IIDXDJLevel: String, Codable {
    case djAAA = "AAA"
    case djAA = "AA"
    case djA = "A"
    case djB = "B"
    case djC = "C"
    case djD = "D"
    case djE = "E"
    case djF = "F"
    case none = "---"

    static let sorted: [IIDXDJLevel] = [
        .djF,
        .djE,
        .djD,
        .djC,
        .djB,
        .djA,
        .djAA,
        .djAAA
    ]
    static var sortedStrings: [String] {
        sorted.map({ $0.rawValue })
    }

    static func < (lhs: IIDXDJLevel, rhs: IIDXDJLevel) -> Bool {
        sorted.firstIndex(of: lhs) ?? 1 < sorted.firstIndex(of: rhs) ?? 0
    }

    static func style(for _: String, colorScheme: ColorScheme) -> any ShapeStyle {
        switch colorScheme {
        case .light:
            return LinearGradient(colors: [.cyan, .blue],
                                  startPoint: .top, endPoint: .bottom)
        case .dark:
            return LinearGradient(colors: [.white, .cyan],
                                  startPoint: .top, endPoint: .bottom)
        @unknown default:
            return Color.primary
        }
    }
}
