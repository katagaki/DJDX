import Foundation

final class IIDXTowerEntry: @unchecked Sendable {
    var playDate: Date = Date.distantPast
    var keyCount: Int = 0
    var scratchCount: Int = 0

    init(playDate: Date, keyCount: Int, scratchCount: Int) {
        self.playDate = playDate
        self.keyCount = keyCount
        self.scratchCount = scratchCount
    }
}
