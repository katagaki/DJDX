import Foundation

struct GITADORANewClearEntry: Identifiable, Hashable {
    let id = UUID()
    let songTitle: String
    let level: String
    let difficulty: GITADORADifficulty
    let clearType: String
    let previousClearType: String
}

struct GITADORANewHighScoreEntry: Identifiable, Hashable {
    let id = UUID()
    let songTitle: String
    let level: String
    let difficulty: GITADORADifficulty
    let newRate: String
    let previousRate: String
    let newRank: String
    let previousRank: String
}

struct GITADORANewRankEntry: Identifiable, Hashable {
    let id = UUID()
    let songTitle: String
    let level: String
    let difficulty: GITADORADifficulty
    let rank: String
    let previousRank: String
}
