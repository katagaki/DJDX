import ActivityKit
import Foundation

struct SessionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var playCount: Int
        var lastSongTitle: String?
        var lastResultSummary: String?
        var bestThisSession: String?
        var heartRate: Int?
        var activeCalories: Int?
        var isProcessing: Bool
    }

    var sessionStart: Date
    var gameShortName: String
    var gameSymbolName: String
}
