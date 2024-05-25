//
//  SortMode.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/25.
//

import Foundation

enum SortMode: String {
    case title = "タイトル"
    case clearType = "クリアタイプ"
    case difficulty = "難易度"

    static let all: [SortMode] = [.title, .clearType, .difficulty]
}
