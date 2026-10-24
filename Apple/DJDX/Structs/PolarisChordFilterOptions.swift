struct PolarisChordFilterOptions: Equatable {
    var difficulties: Set<PolarisChordDifficulty>
    var levels: Set<String>
    var clearTypes: Set<PolarisChordClearType>
    var grades: Set<PolarisChordGrade>

    func matches(_ record: PolarisChordSongRecord) -> Bool {
        if !difficulties.isEmpty, !difficulties.contains(record.difficultyEnum) { return false }
        if !levels.isEmpty, !levels.contains(record.level) { return false }
        if !clearTypes.isEmpty, !clearTypes.contains(record.clearTypeEnum) { return false }
        if !grades.isEmpty, !grades.contains(record.gradeEnum) { return false }
        return true
    }
}
