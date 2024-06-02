//
//  Item.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/18.
//

import Foundation
import SwiftData

let songLevelCSVHeaders: [String] = ["BEGINNER", "NORMAL", "HYPER", "ANOTHER", "LEGGENDARIA"]

@Model
final class IIDXSongRecord: Equatable {
    var version: String = ""
    var title: String = ""
    var genre: String = ""
    var artist: String = ""
    var playCount: Int = 0
    var beginnerScore: IIDXLevelScore = IIDXLevelScore()
    var normalScore: IIDXLevelScore = IIDXLevelScore()
    var hyperScore: IIDXLevelScore = IIDXLevelScore()
    var anotherScore: IIDXLevelScore = IIDXLevelScore()
    var leggendariaScore: IIDXLevelScore = IIDXLevelScore()
    var lastPlayDate: Date = Date.distantPast

    var importGroup: ImportGroup?

    // Based on EPOLIS CSV format
    init(csvRowData: [String: Any]) {
        self.version = csvRowData["バージョン"] as? String ?? ""
        self.title = csvRowData["タイトル"] as? String ?? ""
        self.genre = csvRowData["ジャンル"] as? String ?? ""
        self.artist = csvRowData["アーティスト"] as? String ?? ""
        self.playCount = Int(csvRowData["プレー回数"] as? String ?? "0") ?? 0

        for songLevelCSVHeader in songLevelCSVHeaders {
            let songLevel = IIDXLevel(csvValue: songLevelCSVHeader)
            if songLevel != .unknown {
                let score = IIDXLevelScore(
                    level: songLevel,
                    difficulty: Int(csvRowData["\(songLevelCSVHeader) 難易度"] as? String ?? "0") ?? 0,
                    score: Int(csvRowData["\(songLevelCSVHeader) スコア"] as? String ?? "0") ?? 0,
                    perfectGreatCount: Int(csvRowData["\(songLevelCSVHeader) PGreat"] as? String ?? "0") ?? 0,
                    greatCount: Int(csvRowData["\(songLevelCSVHeader) Great"] as? String ?? "0") ?? 0,
                    missCount: Int(csvRowData["\(songLevelCSVHeader) ミスカウント"] as? String ?? "0") ?? 0,
                    clearType: csvRowData["\(songLevelCSVHeader) クリアタイプ"] as? String ?? "",
                    djLevel: csvRowData["\(songLevelCSVHeader) DJ LEVEL"] as? String ?? ""
                )
                switch songLevelCSVHeader {
                case "BEGINNER": self.beginnerScore = score
                case "NORMAL": self.normalScore = score
                case "HYPER": self.hyperScore = score
                case "ANOTHER": self.anotherScore = score
                case "LEGGENDARIA": self.leggendariaScore = score
                default: break
                }
            }
        }

        if let lastPlayDate = csvRowData["最終プレー日時"] as? String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            self.lastPlayDate = dateFormatter.date(from: lastPlayDate)!
        } else {
            self.lastPlayDate = .distantPast
        }
    }

    func score(for level: IIDXLevel) -> IIDXLevelScore? {
        switch level {
        case .beginner: return beginnerScore
        case .normal: return normalScore
        case .hyper: return hyperScore
        case .another: return anotherScore
        case .leggendaria: return leggendariaScore
        default: return nil
        }
    }

    static func == (lhs: IIDXSongRecord, rhs: IIDXSongRecord) -> Bool {
        return lhs.title == rhs.title &&
        lhs.artist == rhs.artist &&
        lhs.beginnerScore == rhs.beginnerScore &&
        lhs.normalScore == rhs.normalScore &&
        lhs.hyperScore == rhs.hyperScore &&
        lhs.anotherScore == rhs.anotherScore &&
        lhs.leggendariaScore == rhs.leggendariaScore
    }

    static func == (lhs: IIDXSongRecord, rhs: IIDXSong) -> Bool {
        return lhs.title == rhs.title
    }
}

struct IIDXLevelScore: Codable, Equatable {
    var level: IIDXLevel
    var difficulty: Int
    var score: Int
    var perfectGreatCount: Int
    var greatCount: Int
    var missCount: Int
    var clearType: String
    var djLevel: String

    init(level: IIDXLevel,
         difficulty: Int,
         score: Int,
         perfectGreatCount: Int,
         greatCount: Int,
         missCount: Int,
         clearType: String,
         djLevel: String) {
        self.level = level
        self.difficulty = difficulty
        self.score = score
        self.perfectGreatCount = perfectGreatCount
        self.greatCount = greatCount
        self.missCount = missCount
        self.clearType = clearType
        self.djLevel = djLevel
    }

    init() {
        self.level = .unknown
        self.difficulty = 0
        self.score = 0
        self.perfectGreatCount = 0
        self.greatCount = 0
        self.missCount = 0
        self.clearType = "NO PLAY"
        self.djLevel = "---"
    }

    func djLevelEnum() -> IIDXDJLevel {
        IIDXDJLevel(rawValue: djLevel) ?? .none
    }

    static func == (lhs: IIDXLevelScore, rhs: IIDXLevelScore) -> Bool {
        return lhs.level == rhs.level &&
        lhs.difficulty == rhs.difficulty &&
        lhs.score == rhs.score &&
        lhs.clearType == rhs.clearType
    }
}
