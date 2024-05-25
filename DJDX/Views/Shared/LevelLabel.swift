//
//  LevelLabel.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import SwiftUI

struct LevelLabel: View {
    var orientation: LevelLabelOrientation
    var levelType: IIDXLevel
    var score: IIDXLevelScore

    init(levelType: IIDXLevel, songRecord: IIDXSongRecord) {
        self.orientation = .vertical
        switch levelType {
        case .beginner:
            self.levelType = .beginner
            self.score = songRecord.beginnerScore
        case .normal:
            self.levelType = .normal
            self.score = songRecord.normalScore
        case .hyper:
            self.levelType = .hyper
            self.score = songRecord.hyperScore
        case .another:
            self.levelType = .another
            self.score = songRecord.anotherScore
        case .leggendaria:
            self.levelType = .leggendaria
            self.score = songRecord.leggendariaScore
        default:
            self.levelType = .unknown
            self.score = IIDXLevelScore()
        }
    }

    init(levelType: IIDXLevel, score: IIDXLevelScore) {
        self.orientation = .vertical
        self.levelType = levelType
        self.score = score
    }

    init(orientation: LevelLabelOrientation, levelType: IIDXLevel, score: IIDXLevelScore) {
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
        .modifier(LevelLabelGlow(color: foregroundColor()))
        .offset(y: -1.0) // HACK: Fixes weird offset when using black font weight
    }

    func foregroundColor() -> Color {
        switch levelType {
        case .beginner: return Color.green
        case .normal: return Color.blue
        case .hyper: return Color.orange
        case .another: return Color.red
        case .leggendaria: return Color.purple
        default: return Color.primary
        }
    }
}

struct LevelLabelGlow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var color: Color

    func body(content: Content) -> some View {
        switch colorScheme {
        case .light:
            content
                .foregroundStyle(color)
        case .dark:
            content
                .foregroundStyle(.white)
                .shadow(color: color.opacity(0.8), radius: 1.0)
                .shadow(color: color.opacity(0.9), radius: 8.0)
        @unknown default:
            content
        }
    }
}
