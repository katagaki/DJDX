struct SDVXFilterOptions: Equatable {
    var difficulties: Set<SDVXDifficulty>
    var levelBuckets: Set<Double>
    var clearTypes: Set<SDVXClearType>
    var grades: Set<SDVXGrade>

    static func levelBucket(_ level: String) -> Double {
        let value = Double(level) ?? 0.0
        return (value * 2.0).rounded(.down) / 2.0
    }

    func matches(_ record: SDVXSongRecord) -> Bool {
        if !difficulties.isEmpty, !difficulties.contains(record.difficultyEnum) { return false }
        if !levelBuckets.isEmpty, !levelBuckets.contains(Self.levelBucket(record.level)) { return false }
        if !clearTypes.isEmpty, !clearTypes.contains(record.clearTypeEnum) { return false }
        if !grades.isEmpty, !grades.contains(record.gradeEnum) { return false }
        return true
    }
}
