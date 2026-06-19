import Foundation

final class IIDXCapturedPlay: Identifiable, @unchecked Sendable {
    var id: String = UUID().uuidString
    var sessionID: String = ""
    var captureDate: Date = .now
    var source: IIDXCapturedPlaySource = .camera
    var rawImageFilename: String = ""
    var state: IIDXCapturedPlayState = .pending

    var songTitle: String?
    var matchedSongID: Int64?
    var level: IIDXLevel = .unknown
    var difficulty: Int = 0
    var playType: IIDXPlayType = .single
    var exScore: Int = 0
    var perfectGreat: Int = 0
    var great: Int = 0
    var good: Int = 0
    var bad: Int = 0
    var poor: Int = 0
    var miss: Int = 0
    var clearType: String = IIDXClearType.noPlay.rawValue
    var djLevel: String = IIDXDJLevel.none.rawValue

    var ocrConfidence: Double = 0.0
    var parseError: String?
    var processedAt: Date?
    var gaugeData: Data?
    var minHeartRate: Int?
    var maxHeartRate: Int?

    init(id: String = UUID().uuidString,
         sessionID: String,
         captureDate: Date = .now,
         source: IIDXCapturedPlaySource,
         rawImageFilename: String,
         state: IIDXCapturedPlayState = .pending) {
        self.id = id
        self.sessionID = sessionID
        self.captureDate = captureDate
        self.source = source
        self.rawImageFilename = rawImageFilename
        self.state = state
    }

    var isFullyConfident: Bool {
        state == .done && ocrConfidence >= 1.0
    }

    func levelScore() -> IIDXLevelScore {
        IIDXLevelScore(
            level: level,
            difficulty: difficulty,
            score: exScore,
            perfectGreatCount: perfectGreat,
            greatCount: great,
            missCount: miss,
            clearType: clearType,
            djLevel: djLevel
        )
    }

    func apply(_ parse: IIDXResultParse) {
        songTitle = parse.songTitle
        matchedSongID = parse.matchedSongID
        level = parse.level
        difficulty = parse.difficulty
        playType = parse.playType
        exScore = parse.exScore
        perfectGreat = parse.perfectGreat
        great = parse.great
        good = parse.good
        bad = parse.bad
        poor = parse.poor
        miss = parse.miss
        clearType = parse.clearType
        djLevel = parse.djLevel
        ocrConfidence = parse.confidence
    }
}
