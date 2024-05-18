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
final class EPOLISSongRecord {
    var version: String
    var title: String
    var genre: String
    var artist: String
    var playCount: Int
    var beginnerScore: ScoreForLevel
    var normalScore: ScoreForLevel
    var hyperScore: ScoreForLevel
    var anotherScore: ScoreForLevel
    var leggendariaScore: ScoreForLevel
    var lastPlayDate: Date
    
    // Based on EPOLIS CSV format
    init(csvRowData: [String: Any]) {
        self.version = csvRowData["バージョン"] as? String ?? ""
        self.title = csvRowData["タイトル"] as? String ?? ""
        self.genre = csvRowData["ジャンル"] as? String ?? ""
        self.artist = csvRowData["アーティスト"] as? String ?? ""
        self.playCount = Int(csvRowData["プレー回数"] as? String ?? "0") ?? 0

        let emptyScore = ScoreForLevel(
            level: .unknown(name: ""),
            difficulty: 0,
            score: 0,
            perfectGreatCount: 0,
            greatCount: 0,
            missCount: 0,
            clearType: "",
            djLevel: ""
        )
        beginnerScore = emptyScore
        normalScore = emptyScore
        hyperScore = emptyScore
        anotherScore = emptyScore
        leggendariaScore = emptyScore

        for songLevelCSVHeader in songLevelCSVHeaders {
            var songLevel: SongLevel?
            switch songLevelCSVHeader {
            case "BEGINNER": songLevel = .beginner(name: songLevelCSVHeader)
            case "NORMAL": songLevel = .normal(name: songLevelCSVHeader)
            case "HYPER": songLevel = .hyper(name: songLevelCSVHeader)
            case "ANOTHER": songLevel = .another(name: songLevelCSVHeader)
            case "LEGGENDARIA": songLevel = .leggendaria(name: songLevelCSVHeader)
            default: break
            }
            if let songLevel {
                let score = ScoreForLevel(
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
}

struct ScoreForLevel: Codable {
    var level: SongLevel
    var difficulty: Int
    var score: Int
    var perfectGreatCount: Int
    var greatCount: Int
    var missCount: Int
    var clearType: String
    var djLevel: String
}

enum SongLevel: Codable {
    case beginner(name: String)
    case normal(name: String)
    case hyper(name: String)
    case another(name: String)
    case leggendaria(name: String)
    case unknown(name: String)
}
