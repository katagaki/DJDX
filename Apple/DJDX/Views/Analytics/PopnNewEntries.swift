import Foundation

struct PopnNewClearEntry: Identifiable, Hashable {
    let id = UUID()
    let songTitle: String
    let level: Int
    let difficulty: PopnDifficulty
    let medal: String
    let previousMedal: String
}

struct PopnNewHighScoreEntry: Identifiable, Hashable {
    let id = UUID()
    let songTitle: String
    let level: Int
    let difficulty: PopnDifficulty
    let newScore: Int
    let previousScore: Int
    let newRank: String
    let previousRank: String
}

struct PopnNewRankEntry: Identifiable, Hashable {
    let id = UUID()
    let songTitle: String
    let level: Int
    let difficulty: PopnDifficulty
    let rank: String
    let previousRank: String
}
