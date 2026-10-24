//
//  PolarisChordNewEntries.swift
//  DJDX
//
//  "前回のプレー" (Last Play) delta entries for Polaris Chord. Mirrors the
//  SDVX entry types: one row per chart, carrying a single chart's level
//  (String) and difficulty (PolarisChordDifficulty). Polaris Chord records
//  have no artist.
//

import Foundation

struct PolarisChordNewClearEntry: Identifiable, Hashable {
    let id = UUID()
    let songTitle: String
    let level: String
    let difficulty: PolarisChordDifficulty
    let clearType: String
    let previousClearType: String
}

struct PolarisChordNewHighScoreEntry: Identifiable, Hashable {
    let id = UUID()
    let songTitle: String
    let level: String
    let difficulty: PolarisChordDifficulty
    let newScore: Int
    let previousScore: Int
    let newGrade: String
    let previousGrade: String
}

struct PolarisChordNewGradeEntry: Identifiable, Hashable {
    let id = UUID()
    let songTitle: String
    let level: String
    let difficulty: PolarisChordDifficulty
    let grade: String
    let previousGrade: String
}
