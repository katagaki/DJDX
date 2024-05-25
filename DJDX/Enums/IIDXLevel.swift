//
//  IIDXLevel.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/25.
//

import Foundation

enum IIDXLevel: String, Codable {
    case all = "すべて"
    case beginner = "BEGINNER"
    case normal = "NORMAL"
    case hyper = "HYPER"
    case another = "ANOTHER"
    case leggendaria = "LEGGENDARIA"
    case unknown = ""

    static let sortLevels: [IIDXLevel] = [.all, .beginner, .normal, .hyper, .another, .leggendaria]
}
