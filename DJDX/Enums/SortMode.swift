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
    case difficultyAscending = "難易度（昇順）"
    case difficultyDescending = "難易度（降順）"
    case lastPlayDate = "最終プレー日時"

    static let all: [SortMode] = [.title, .clearType, .difficultyAscending, .difficultyDescending, .lastPlayDate]
}
