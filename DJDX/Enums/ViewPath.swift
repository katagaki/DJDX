//
//  ViewPath.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import Foundation

enum ViewPath: Hashable {
    case scoreViewer(songRecord: IIDXSongRecord)
    case textageViewer(songTitle: String,
                       level: IIDXLevel,
                       playSide: IIDXPlaySide)
    case clearLampOverviewGraph
    case clearLampPerDifficultyGraph
    case scoreRatePerDifficultyGraph
    case importerWeb
    case importerManual
    case moreAttributions
}
