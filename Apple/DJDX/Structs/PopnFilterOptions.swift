struct PopnFilterOptions: Equatable {
    var difficulties: Set<PopnDifficulty>
    var levels: Set<String>
    var clearTypes: Set<PopnClearType>
    var ranks: Set<PopnRank>

    func matches(_ record: PopnSongRecord) -> Bool {
        if !difficulties.isEmpty, !difficulties.contains(record.difficultyEnum) { return false }
        if !levels.isEmpty, !levels.contains(String(record.level)) { return false }
        if !clearTypes.isEmpty, !clearTypes.contains(record.clearType) { return false }
        if !ranks.isEmpty, !ranks.contains(record.rankEnum) { return false }
        return true
    }
}
