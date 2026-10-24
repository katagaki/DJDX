//
//  SDVXNewEntries.swift
//  DJDX
//
//  "前回のプレー" (Last Play) delta entries for SDVX. Mirrors the IIDX
//  NewClearEntry / NewHighScoreEntry / NewDJLevelEntry types, but SDVX-shaped:
//  the SDVX CSV is one row per chart, so each entry carries a single chart's
//  level (String) and difficulty (SDVXDifficulty). SDVX records have no artist.
//

import Foundation

struct SDVXNewClearEntry: Identifiable, Hashable {
    let id = UUID()
    let songTitle: String
    let level: String
    let difficulty: SDVXDifficulty
    let clearType: String
    let previousClearType: String
}

struct SDVXNewHighScoreEntry: Identifiable, Hashable {
    let id = UUID()
    let songTitle: String
    let level: String
    let difficulty: SDVXDifficulty
    let newScore: Int
    let previousScore: Int
    let newGrade: String
    let previousGrade: String
}

struct SDVXNewGradeEntry: Identifiable, Hashable {
    let id = UUID()
    let songTitle: String
    let level: String
    let difficulty: SDVXDifficulty
    let grade: String
    let previousGrade: String
}
