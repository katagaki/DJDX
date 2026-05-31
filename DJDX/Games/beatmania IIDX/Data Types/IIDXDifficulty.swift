//
//  IIDXDifficulty.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/02.
//

import Foundation

enum IIDXDifficulty: Int, Codable {
    case all = -1
    case level1 = 1
    case level2 = 2
    case level3 = 3
    case level4 = 4
    case level5 = 5
    case level6 = 6
    case level7 = 7
    case level8 = 8
    case level9 = 9
    case level10 = 10
    case level11 = 11
    case level12 = 12

    static let sorted: [IIDXDifficulty] = [
        .level1,
        .level2,
        .level3,
        .level4,
        .level5,
        .level6,
        .level7,
        .level8,
        .level9,
        .level10,
        .level11,
        .level12
    ]

    static let sortedInts: [Int] = Array(1...12)
}
