//
//  ChartRadarData.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/03/08.
//

import Foundation

struct ChartRadarData {
    let title: String
    let playType: String
    let difficulty: Int
    let noteCount: Int
    let radarData: RadarData

    func difficultyLevel() -> IIDXLevel {
        switch difficulty {
        case 0: return .beginner
        case 1: return .normal
        case 2: return .hyper
        case 3: return .another
        case 4: return .leggendaria
        default: return .unknown
        }
    }
}
