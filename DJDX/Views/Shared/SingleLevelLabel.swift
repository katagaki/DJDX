//
//  SingleLevelLabel.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import SwiftUI

struct SingleLevelLabel: View {

    var orientation: LevelLabelOrientation
    var levelType: SongLevel
    var score: ScoreForLevel

    init(levelType: SongLevel, score: ScoreForLevel) {
        self.orientation = .vertical
        self.levelType = levelType
        self.score = score
    }

    init(orientation: LevelLabelOrientation, levelType: SongLevel, score: ScoreForLevel) {
        self.orientation = orientation
        self.levelType = levelType
        self.score = score
    }

    var body: some View {
        Group {
            switch orientation {
            case .vertical:
                VStack(alignment: .center) {
                    Text(String(score.difficulty))
                        .italic()
                        .font(.system(size: 16.0))
                        .fontWeight(.black)
                    Text(verbatim: levelType.rawValue)
                        .font(.system(size: 10.0))
                        .fontWeight(.semibold)
                }
            case .horizontal:
                HStack(alignment: .center, spacing: 12.0) {
                    Text(String(score.difficulty))
                        .italic()
                        .font(.system(size: 18.0))
                        .fontWeight(.black)
                    Text(verbatim: levelType.rawValue)
                        .font(.system(size: 12.0))
                        .fontWeight(.semibold)
                }
            }
        }
        .kerning(-0.2)
        .lineLimit(1)
        .foregroundStyle(foregroundColor())
    }

    func foregroundColor() -> Color {
        switch levelType {
        case .beginner: return Color.green
        case .normal: return Color.blue
        case .hyper: return Color.orange
        case .another: return Color.red
        case .leggendaria: return Color.purple
        case .unknown: return Color.primary
        }
    }
}
