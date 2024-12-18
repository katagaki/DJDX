//
//  ViewPath.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import Foundation

enum ViewPath: Hashable {
    case scoreViewer(songRecord: IIDXSongRecord)
    case scoreHistory(songTitle: String,
                      level: IIDXLevel,
                      noteCount: Int?)
    case textageViewer(songTitle: String,
                       level: IIDXLevel,
                       playSide: IIDXPlaySide,
                       playType: IIDXPlayType)
    case clearTypeOverviewGraph
    case clearTypePerDifficultyGraph
    case scoreRatePerDifficultyGraph
    case trendsClearTypeGraph
    case trendsDJLevelGraph
    case importerWebIIDXSingle
    case importerWebIIDXDouble
    case importerManual
    case moreBemaniWikiCharts
    case moreAppIcon
    case moreAttributions
}
