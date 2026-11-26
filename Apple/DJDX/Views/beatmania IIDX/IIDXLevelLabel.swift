import SwiftUI

struct IIDXLevelLabel: View {
    var layout: LevelBadgeLayout
    var levelType: IIDXLevel
    var score: IIDXLevelScore

    init(levelType: IIDXLevel, songRecord: IIDXSongRecord) {
        self.layout = .vertical
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
        self.layout = .vertical
        self.levelType = levelType
        self.score = score
    }

    init(layout: LevelBadgeLayout, levelType: IIDXLevel, score: IIDXLevelScore) {
        self.layout = layout
        self.levelType = levelType
        self.score = score
    }

    var body: some View {
        let name = String(localized: String.LocalizationValue(levelType.rawValue))
        LevelBadge(name: layout == .compact ? String(name.prefix(1)) : name,
                   level: String(score.difficulty), tint: foregroundColor(), layout: layout)
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
