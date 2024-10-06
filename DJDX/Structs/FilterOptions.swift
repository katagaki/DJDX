//
//  FilterOptions.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/10/05.
//

struct FilterOptions: Equatable {
    var playType: IIDXPlayType
    var onlyPlayDataWithScores: Bool
    var level: IIDXLevel
    var difficulty: IIDXDifficulty
    var clearType: IIDXClearType

    static func == (lhs: FilterOptions, rhs: FilterOptions) -> Bool {
        lhs.playType == rhs.playType &&
        lhs.onlyPlayDataWithScores == rhs.onlyPlayDataWithScores &&
        lhs.level == rhs.level &&
        lhs.difficulty == rhs.difficulty &&
        lhs.clearType == rhs.clearType
    }
}
