import Foundation

enum ScoresPath: Hashable {
    case scoreViewer(songRecord: IIDXSongRecord, initialLevel: IIDXLevel = .all)
    case textageViewer(legacyURL: URL?, chartViewerURL: URL?)
}

enum AnalyticsPath: Hashable {
    case clearTypeOverviewGraph
    case gradeBreakdownDetail
    case progressDetail(kind: IIDXProgressKind)
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
    case newClearLampsDetail
    case newScoreUpdatesDetail
    case newAAADetail
    case newAADetail
    case newADetail
    case djLevelSuggestionsDetail
    case clearLampSuggestionsDetail
    case notPlayedRecentlySuggestionsDetail
}

enum AnalyticsGoalPath: Hashable {
    case detail(id: UUID)
}

enum SDVXScoresPath: Hashable {
    case scoreViewer(songRecord: SDVXSongRecord)
    case chartViewer(chart: SDVXInChart)
}

enum DDRScoresPath: Hashable {
    case scoreViewer(songRecord: DDRSongRecord)
}

enum SDVXAnalyticsPath: Hashable {
    case clearBreakdownDetail
    case gradeBreakdownDetail
    case volforceTrendDetail
    case newHighScoresDetail
    case newClearsDetail(clearType: String)
    case newGradesDetail(grade: String)
    case volforceSuggestionsDetail
}

enum PolarisChordAnalyticsPath: Hashable {
    case clearBreakdownDetail
    case gradeBreakdownDetail
    case newHighScoresDetail
    case newClearsDetail(clearType: String)
    case newGradesDetail(grade: String)
}

enum GITADORAAnalyticsPath: Hashable {
    case skillDetail
    case clearBreakdownDetail
    case rankBreakdownDetail
    case newHighScoresDetail
    case newClearsDetail(clearType: String)
    case newRanksDetail(rank: String)
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
