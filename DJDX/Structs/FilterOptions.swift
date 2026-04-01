//
//  FilterOptions.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/10/05.
//

struct FilterOptions: Equatable {
    var playType: IIDXPlayType
    var onlyPlayDataWithScores: Bool
    var levels: Set<IIDXLevel>
    var difficulties: Set<IIDXDifficulty>
    var clearTypes: Set<IIDXClearType>
    var djLevels: Set<IIDXDJLevel>
    var versions: Set<String>
}
