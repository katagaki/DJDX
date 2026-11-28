import SwiftUI

extension ShareCardEntry {

    static func iidxLampStyle(for clearType: String) -> AnyShapeStyle {
        switch clearType {
        case "FULLCOMBO CLEAR":
            AnyShapeStyle(LinearGradient(
                colors: [.red, .orange, .yellow, .green, .blue, .indigo, .purple],
                startPoint: .top,
                endPoint: .bottom
            ))
        case "CLEAR": AnyShapeStyle(Color.cyan)
        case "EASY CLEAR": AnyShapeStyle(Color.green)
        case "ASSIST CLEAR": AnyShapeStyle(Color.purple)
        case "HARD CLEAR": AnyShapeStyle(Color.white)
        case "EX HARD CLEAR": AnyShapeStyle(Color.orange)
        case "FAILED": AnyShapeStyle(Color.red)
        default: AnyShapeStyle(Color.clear)
        }
    }

    static func iidxDifficultyColor(for level: IIDXLevel) -> Color {
        switch level {
        case .beginner: .green
        case .normal: .blue
        case .hyper: .orange
        case .another: .red
        case .leggendaria: .purple
        default: .white
        }
    }

    init(iidxSongRecord songRecord: IIDXSongRecord, level: IIDXLevel,
         score: IIDXLevelScore, scoreRate: Float?, iidxVersion: IIDXVersion) {
        var metrics: [ShareCardMetric] = []
        if score.score != 0 {
            if !score.djLevel.isEmpty, score.djLevel != "---" {
                metrics.append(ShareCardMetric(score.djLevel,
                                               style: AnyShapeStyle(IIDXDJLevel.style(for: score.djLevel)),
                                               typeface: .grade))
            }
            if let scoreRate {
                metrics.append(ShareCardMetric(
                    scoreRate.formatted(.percent.precision(.fractionLength(1))),
                    style: Color.white.opacity(0.7),
                    typeface: .score
                ))
            }
            metrics.append(ShareCardMetric(String(score.score), style: Color.iidxScore, typeface: .score))
        }
        self.init(
            title: songRecord.title,
            subtitle: songRecord.artist,
            lampStyle: Self.iidxLampStyle(for: score.clearType),
            levelText: String(score.difficulty),
            difficultyText: String(localized: String.LocalizationValue(level.rawValue)),
            difficultyColor: Self.iidxDifficultyColor(for: level),
            metrics: metrics,
            titleStyle: AnyShapeStyle(iidxVersion.rowTitleTextColor(for: songRecord.version, level: level,
                                                                    colorScheme: .dark)),
            titleStrokeColor: iidxVersion.rowTitleStrokeColor(for: songRecord.version, level: level,
                                                              colorScheme: .dark),
            playDate: score.score != 0 || score.clearType != "NO PLAY" ? songRecord.lastPlayDate : .distantPast
        )
    }

    init(sdvxSongRecord record: SDVXSongRecord) {
        var metrics: [ShareCardMetric] = []
        if record.gradeEnum != .none && record.gradeEnum != .unknown {
            metrics.append(ShareCardMetric(record.grade, style: LinearGradient.sdvxGrade, typeface: .grade))
        }
        if record.highScore > 0 {
            metrics.append(ShareCardMetric(String(record.highScore), style: LinearGradient.sdvxScore, typeface: .score))
        }
        metrics.append(ShareCardMetric(record.clearTypeEnum.abbreviation, style: record.clearTypeEnum.color,
                                       typeface: .clearType))
        self.init(
            title: record.title,
            lampStyle: AnyShapeStyle(record.clearTypeEnum.color),
            levelText: record.level,
            difficultyText: record.difficultyEnum.abbreviation,
            difficultyColor: record.difficultyEnum.color,
            metrics: metrics
        )
    }

    init(ddrSongRecord record: DDRSongRecord) {
        var metrics: [ShareCardMetric] = []
        if record.score > 0 {
            metrics.append(ShareCardMetric(
                String(record.score),
                style: LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom),
                typeface: .score
            ))
        }
        if !record.rankDisplay.isEmpty {
            metrics.append(ShareCardMetric(record.rankDisplay, style: DDRSongRecord.rankColor(forStem: record.rank),
                                           typeface: .grade))
        }
        if !record.clearDisplay.isEmpty {
            metrics.append(ShareCardMetric(record.clearDisplay,
                                           style: DDRSongRecord.clearColor(for: record.clearKind),
                                           typeface: .clearType))
        }
        self.init(
            title: record.title,
            lampStyle: AnyShapeStyle(DDRSongRecord.clearColor(for: record.clearKind)),
            levelText: record.level > 0 ? String(record.level) : "-",
            difficultyText: record.difficultyEnum.rawValue,
            difficultyColor: record.difficultyEnum.color,
            metrics: metrics
        )
    }

    init(polarisChordSongRecord record: PolarisChordSongRecord) {
        var metrics: [ShareCardMetric] = []
        if !record.achievementRate.isEmpty {
            metrics.append(ShareCardMetric(
                "\(record.achievementRate)%",
                style: LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom),
                typeface: .score
            ))
        }
        if record.gradeEnum != .none && record.gradeEnum != .unknown {
            metrics.append(ShareCardMetric(record.grade,
                                           style: AnyShapeStyle(record.gradeEnum.style(colorScheme: .dark)),
                                           typeface: .grade))
        }
        metrics.append(ShareCardMetric(record.clearTypeEnum.abbreviation, style: record.clearTypeEnum.color,
                                       typeface: .clearType))
        self.init(
            title: record.title,
            lampStyle: AnyShapeStyle(record.clearTypeEnum.color),
            levelText: record.level,
            difficultyText: record.difficultyEnum.rawValue,
            difficultyColor: record.difficultyEnum.color,
            metrics: metrics
        )
    }
}

extension ShareCardProfile {

    static func iidx(playType: IIDXPlayType) -> ShareCardProfile {
        let defaults = UserDefaults.standard
        var ratings: [ShareCardRating] = []
        let rankKey = playType == .single ? "Profile.IIDX.SPRank" : "Profile.IIDX.DPRank"
        if let rank = defaults.string(forKey: rankKey), !rank.isEmpty, rank != "--" {
            ratings.append(ShareCardRating(label: "", value: rank))
        }
        let radarPrefix = playType == .single ? "NotesRadar.SP" : "NotesRadar.DP"
        let shared = SharedContainer.defaults
        var radar: RadarData?
        if shared.object(forKey: "\(radarPrefix).Notes") != nil {
            let radarData = RadarData(
                notes: shared.double(forKey: "\(radarPrefix).Notes"),
                chord: shared.double(forKey: "\(radarPrefix).Chord"),
                peak: shared.double(forKey: "\(radarPrefix).Peak"),
                charge: shared.double(forKey: "\(radarPrefix).Charge"),
                scratch: shared.double(forKey: "\(radarPrefix).Scratch"),
                soflan: shared.double(forKey: "\(radarPrefix).Soflan")
            )
            radar = radarData
        }
        let qproPath = SharedContainer.imagesURL.appendingPathComponent("Qpro.png").path
        return ShareCardProfile(
            playerName: defaults.string(forKey: "Profile.IIDX.DJName"),
            ratings: ratings,
            avatar: UIImage(contentsOfFile: qproPath),
            radar: radar
        )
    }

    static func sdvx() -> ShareCardProfile {
        let defaults = UserDefaults.standard
        var ratings: [ShareCardRating] = []
        if let volforce = defaults.string(forKey: "SDVXProfile.Volforce"), !volforce.isEmpty {
            ratings.append(ShareCardRating(label: "VOLFORCE", value: volforce))
        }
        let name = defaults.string(forKey: "SDVXProfile.PlayerName")?
            .replacingOccurrences(of: "\n", with: " ")
        return ShareCardProfile(playerName: name, ratings: ratings)
    }

    static func ddr(style: DDRPlayStyle) -> ShareCardProfile {
        let defaults = UserDefaults.standard
        var ratings: [ShareCardRating] = []
        if let flareSkill = defaults.string(forKey: "DDRProfile.FlareSkill.\(style.rawValue)"), !flareSkill.isEmpty {
            ratings.append(ShareCardRating(label: "FLARE SKILL", value: flareSkill))
        }
        return ShareCardProfile(playerName: defaults.string(forKey: "DDRProfile.DancerName"), ratings: ratings)
    }

    static func polarisChord() -> ShareCardProfile {
        let defaults = UserDefaults.standard
        var ratings: [ShareCardRating] = []
        if let paSkill = defaults.string(forKey: "PolarisChordProfile.PASkill"), !paSkill.isEmpty {
            ratings.append(ShareCardRating(label: "PA SKILL", value: paSkill))
        }
        return ShareCardProfile(playerName: defaults.string(forKey: "PolarisChordProfile.PlayerName"),
                                ratings: ratings)
    }
}
