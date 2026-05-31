//
//  ViewPath.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import Foundation

enum ScoresPath: Hashable {
    case scoreViewer(songRecord: IIDXSongRecord, initialLevel: IIDXLevel = .all)
    case textageViewer(songTitle: String,
                       level: IIDXLevel,
                       playSide: IIDXPlaySide,
                       playType: IIDXPlayType)
}

enum AnalyticsPath: Hashable {
    case clearTypeOverviewGraph
    case clearTypePerDifficultyGraph
    case scoreRatePerDifficultyGraph
    case trendsClearTypeGraph
    case trendsDJLevelGraph
    case clearTypeForLevel(difficulty: Int)
    case clearTypeTrendsForLevel(difficulty: Int)
    case djLevelForLevel(difficulty: Int)
    case djLevelTrendsForLevel(difficulty: Int)
    case newClearsDetail
    case newAssistClearsDetail
    case newEasyClearsDetail
    case newFullComboClearDetail
    case newHardClearDetail
    case newExHardClearDetail
    case newFailedDetail
    case newHighScoresDetail
    case newAAADetail
    case newAADetail
    case newADetail
}

enum ImportPath: Hashable {
    case importerWebIIDXSingle
    case importerWebIIDXDouble
    case importerWebIIDXTower
    case importerManual
}

enum MorePath: Hashable {
    case moreExternalDataSources
    case moreAttributions
}

enum TowerPath: Hashable {
    case recent
    case totals
}
