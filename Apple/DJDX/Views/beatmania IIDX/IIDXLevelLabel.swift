import SwiftUI

struct IIDXLevelLabel: View {
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
        let name = String(localized: String.LocalizationValue(levelType.rawValue))
        switch orientation {
        case .vertical:
            LevelBadge(name: name, level: String(score.difficulty), tint: foregroundColor())
        case .horizontal:
            LevelBadge(name: String(name.prefix(1)), level: String(score.difficulty),
                       tint: foregroundColor(), layout: .compact)
        }
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
