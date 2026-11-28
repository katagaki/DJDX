struct GITADORAFilterOptions: Equatable {
    var difficulties: Set<GITADORADifficulty>
    var levels: Set<String>
    var clearTypes: Set<GITADORAClearType>
    var ranks: Set<GITADORARank>

    func matches(_ record: GITADORASongRecord) -> Bool {
        if !difficulties.isEmpty, !difficulties.contains(record.difficultyEnum) { return false }
        if !levels.isEmpty, !levels.contains(record.levelBucket) { return false }
        if !clearTypes.isEmpty, !clearTypes.contains(record.clearTypeEnum) { return false }
        if !ranks.isEmpty, !ranks.contains(record.rankEnum) { return false }
        return true
    }
}
