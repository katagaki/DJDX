//
//  IIDXLevel.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/25.
//

import Foundation
import SwiftUI

enum IIDXLevel: String, CaseIterable, Codable {
    case all = "Shared.All"
    case beginner = "Shared.Level.Beginner"
    case normal = "Shared.Level.Normal"
    case hyper = "Shared.Level.Hyper"
    case another = "Shared.Level.Another"
    case leggendaria = "Shared.Level.Leggendaria"
    case unknown = ""

    static let sorted: [IIDXLevel] = [
        .beginner,
        .normal,
        .hyper,
        .another,
        .leggendaria
    ]

    private var extraRawValues: [String] {
        switch self {
        case .all: return ["すべて", "Shared.All"]
        case .beginner: return ["BEGINNER", "Shared.Level.Beginner"]
        case .normal: return ["NORMAL", "Shared.Level.Normal"]
        case .hyper: return ["HYPER", "Shared.Level.Hyper"]
        case .another: return ["ANOTHER", "Shared.Level.Another"]
        case .leggendaria: return ["LEGGENDARIA", "Shared.Level.Leggendaria"]
        case .unknown: return []
        }
    }

    init(csvValue: String) {
        switch csvValue {
        case "BEGINNER": self = .beginner
        case "NORMAL": self = .normal
        case "HYPER": self = .hyper
        case "ANOTHER": self = .another
        case "LEGGENDARIA": self = .leggendaria
        default: self = .unknown
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let decodedValue = try container.decode(String.self)
        if let decodedEnum = IIDXLevel.allCases.first(where: { enumCase in
            let possibleValues = [enumCase.rawValue.lowercased()] + enumCase.extraRawValues.map { $0.lowercased() }
            return possibleValues.contains { $0 == decodedValue.lowercased() }
        }) {
            self = decodedEnum
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid IIDX level")
        }
    }

    func code() -> String {
        switch self {
        case .beginner: return "B"
        case .normal: return "N"
        case .hyper: return "H"
        case .another: return "A"
        case .leggendaria: return "L"
        case .all, .unknown: return ""
        }
    }

    var scoreKeyPath: KeyPath<IIDXSongRecord, IIDXLevelScore>? {
        switch self {
        case .beginner: return \.beginnerScore
        case .normal: return \.normalScore
        case .hyper: return \.hyperScore
        case .another: return \.anotherScore
        case .leggendaria: return \.leggendariaScore
        default: return nil
        }
    }

    var noteCountKeyPath: KeyPath<IIDXNoteCount, Int?>? {
        switch self {
        case .beginner: return \.beginnerNoteCount
        case .normal: return \.normalNoteCount
        case .hyper: return \.hyperNoteCount
        case .another: return \.anotherNoteCount
        case .leggendaria: return \.leggendariaNoteCount
        default: return nil
        }
    }

    var color: Color {
        switch self {
        case .beginner: return .green
        case .normal: return .blue
        case .hyper: return .orange
        case .another: return .red
        case .leggendaria: return .purple
        default: return .primary
        }
    }
}
