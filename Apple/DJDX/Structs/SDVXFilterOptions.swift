struct SDVXFilterOptions: Equatable {
    var difficulties: Set<SDVXDifficulty>
    var levelBuckets: Set<Double>
    var clearTypes: Set<SDVXClearType>
    var grades: Set<SDVXGrade>
    var scoreBelow: Int = 0

    static let scoreThresholds: [Int] = [
        9_000_000, 9_500_000, 9_700_000, 9_800_000, 9_900_000, 9_950_000, 9_980_000, 10_000_000
    ]

    static func levelBucket(_ level: String) -> Double {
        let value = Double(level) ?? 0.0
        return (value * 2.0).rounded(.down) / 2.0
    }

    func matches(_ record: SDVXSongRecord) -> Bool {
        if !difficulties.isEmpty, !difficulties.contains(record.difficultyEnum) { return false }
        if !levelBuckets.isEmpty, !levelBuckets.contains(Self.levelBucket(record.level)) { return false }
        if !clearTypes.isEmpty, !clearTypes.contains(record.clearTypeEnum) { return false }
        if !grades.isEmpty, !grades.contains(record.gradeEnum) { return false }
        if scoreBelow > 0, record.highScore <= 0 || record.highScore >= scoreBelow { return false }
        return true
    }
}
