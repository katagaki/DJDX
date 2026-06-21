import ActivityKit
import Foundation

struct SessionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var playCount: Int
        var lastSongTitle: String?
        var lastDJLevel: String?
        var lastClearType: String?
        var lastScore: Int?
        var lastResultSummary: String?
        var bestThisSession: String?
        var heartRate: Int?
        var activeCalories: Int?
        var isPaused: Bool = false
        var pausedElapsed: TimeInterval?
        var runningStart: Date?
        var isProcessing: Bool
    }

    var sessionID: String
    var sessionStart: Date
    var gameShortName: String
    var gameIconAssetName: String
}
