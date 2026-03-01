//
//  SortMode.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/25.
//

import Foundation

enum SortMode: String, CaseIterable, Codable {
    case title = "Shared.Sort.Title"
    case clearType = "Shared.IIDX.ClearType"
    case djLevel = "Shared.IIDX.DJLevel"
    case scoreRate = "Shared.Sort.ScoreRate"
    case score = "Shared.Sort.Score"
    case missCount = "Shared.Sort.MissCount"
    case difficulty = "Shared.Sort.Difficulty"
    case lastPlayDate = "Shared.Sort.LastPlayDate"

    static let whenLevelFiltered: [SortMode] = [
        .title,
        .clearType,
        .djLevel,
        .scoreRate,
        .score,
        .missCount,
        .difficulty,
        .lastPlayDate
    ]

    static let whenDifficultyFiltered: [SortMode] = [
        .title,
        .clearType,
        .djLevel,
        .scoreRate,
        .score,
        .missCount,
        .lastPlayDate
    ]

    private var extraRawValues: [String] {
        switch self {
        case .title: return ["タイトル", "Shared.Sort.Title"]
        case .clearType: return ["クリアタイプ", "Shared.Sort.ClearType", "Shared.IIDX.ClearType"]
        case .djLevel: return ["DJ LEVEL", "Shared.Sort.DJLevel", "Shared.IIDX.DJLevel"]
        case .scoreRate: return ["クリアレート", "Shared.Sort.ScoreRate"]
        case .score: return [
            "スコア", "Shared.Sort.Score",
            "スコア（昇順）", "Shared.Sort.ScoreAscending",
            "スコア（降順）", "Shared.Sort.ScoreDescending"
        ]
        case .missCount: return ["MISS COUNT", "Shared.Sort.MissCount"]
        case .difficulty: return [
            "レベル", "Shared.Sort.Difficulty",
            "難易度（昇順）", "Shared.Sort.DifficultyAscending",
            "難易度（降順）", "Shared.Sort.DifficultyDescending"
        ]
        case .lastPlayDate: return ["最終プレー日時", "Shared.Sort.LastPlayDate"]
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let decodedValue = try container.decode(String.self)
        if let decodedEnum = SortMode.allCases.first(where: { enumCase in
            let possibleValues = [enumCase.rawValue.lowercased()] + enumCase.extraRawValues.map { $0.lowercased() }
            return possibleValues.contains { $0 == decodedValue.lowercased() }
        }) {
            self = decodedEnum
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid sort mode")
        }
    }
}

enum SortOrder: String, CaseIterable, Codable {
    case ascending = "Shared.Sort.Ascending"
    case descending = "Shared.Sort.Descending"
}
