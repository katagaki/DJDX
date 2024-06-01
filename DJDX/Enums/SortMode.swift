//
//  SortMode.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/25.
//

import Foundation

enum SortMode: String, CaseIterable, Codable {
    case title = "Shared.Sort.Title"
    case clearType = "Shared.Sort.ClearType"
    case scoreAscending = "Shared.Sort.ScoreAscending"
    case scoreDescending = "Shared.Sort.ScoreDescending"
    case difficultyAscending = "Shared.Sort.DifficultyAscending"
    case difficultyDescending = "Shared.Sort.DifficultyDescending"
    case lastPlayDate = "Shared.Sort.LastPlayDate"

    static let all: [SortMode] = [
        .title,
        .clearType,
        .scoreAscending,
        .scoreDescending,
        .difficultyAscending,
        .difficultyDescending,
        .lastPlayDate
    ]

    private var extraRawValues: [String] {
        switch self {
        case .title: return ["タイトル", "Shared.Sort.Title"]
        case .clearType: return ["クリアタイプ", "Shared.Sort.ClearType"]
        case .scoreAscending: return ["スコア（昇順）", "Shared.Sort.ScoreAscending"]
        case .scoreDescending: return ["スコア（降順）", "Shared.Sort.ScoreDescending"]
        case .difficultyAscending: return ["難易度（昇順）", "Shared.Sort.DifficultyAscending"]
        case .difficultyDescending: return ["難易度（降順）", "Shared.Sort.DifficultyDescending"]
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
