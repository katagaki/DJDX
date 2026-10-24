struct DDRFilterOptions: Equatable {
    var onlyPlayedCharts: Bool
    var difficulties: Set<DDRDifficulty>
    var levels: Set<Int>
    var clearLamps: Set<String>
    var ranks: Set<String>

    func matches(_ record: DDRSongRecord) -> Bool {
        if onlyPlayedCharts, !record.hasScore { return false }
        if !difficulties.isEmpty, !difficulties.contains(record.difficultyEnum) { return false }
        if !levels.isEmpty, !levels.contains(record.level) { return false }
        if !clearLamps.isEmpty, !clearLamps.contains(record.clearKind) { return false }
        if !ranks.isEmpty, !ranks.contains(record.rank) { return false }
        return true
    }
}
