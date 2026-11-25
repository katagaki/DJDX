import Foundation

enum AnalyticsGoalEvaluator {

    static func progress(
        for goals: [AnalyticsGoal],
        iidxVersion: IIDXVersion,
        sdvxVersion: SDVXVersion,
        ddrVersion: DDRVersion
    ) async -> [AnalyticsGoalProgress] {
        guard let game = goals.first?.game else { return [] }
        let histories: [UUID: [AnalyticsGoalPoint]]
        switch game {
        case .iidxArcade, .iidxInfinitas:
            histories = await iidxHistories(for: goals, version: iidxVersion)
        case .soundVoltex:
            histories = await sdvxHistories(for: goals, version: sdvxVersion)
        case .danceDanceRevolution:
            histories = await ddrHistories(for: goals, version: ddrVersion)
        case .polarisChord:
            histories = [:]
        }
        return goals.map { AnalyticsGoalProgress(goal: $0, history: histories[$0.id] ?? []) }
    }

    // MARK: - IIDX

    static func iidxHistories(for goals: [AnalyticsGoal], version: IIDXVersion) async -> [UUID: [AnalyticsGoalPoint]] {
        let reader = IIDXReader()
        let groups = await reader.importGroups(for: version)
        guard !groups.isEmpty else { return [:] }
        var result: [UUID: [AnalyticsGoalPoint]] = [:]
        for playStyle in Set(goals.map(\.playStyle)) {
            let playType = IIDXPlayType(rawValue: playStyle) ?? .single
            let counts = await reader.aggregatedCounts(for: groups.map(\.id), playType: playType)
            for goal in goals where goal.playStyle == playStyle {
                let source = goal.kind == .clearCount ? counts.clearType : counts.djLevel
                result[goal.id] = groups.compactMap { group in
                    guard let perDifficulty = source[group.id] else { return nil }
                    return AnalyticsGoalPoint(date: group.importDate,
                                              value: Double(iidxCount(perDifficulty, goal: goal)))
                }
            }
        }
        return result
    }

    static func iidxCount(_ perDifficulty: [Int: [String: Int]], goal: AnalyticsGoal) -> Int {
        let ranking = goal.kind == .clearCount
            ? IIDXClearType.ascending.map(\.rawValue)
            : IIDXDJLevel.sortedStrings
        guard let thresholdRank = ranking.firstIndex(of: goal.threshold) else { return 0 }
        var total = 0
        for (difficulty, counts) in perDifficulty where goal.level == 0 || difficulty == goal.level {
            for (key, count) in counts {
                if let rank = ranking.firstIndex(of: key), rank >= thresholdRank {
                    total += count
                }
            }
        }
        return total
    }

    // MARK: - SOUND VOLTEX

    static func sdvxHistories(for goals: [AnalyticsGoal], version: SDVXVersion) async -> [UUID: [AnalyticsGoalPoint]] {
        let reader = SDVXReader()
        let groups = await reader.importGroups(for: version).reversed()
        var result: [UUID: [AnalyticsGoalPoint]] = [:]
        for group in groups {
            let records = await reader.songRecords(for: group.id)
            guard !records.isEmpty else { continue }
            for goal in goals {
                result[goal.id, default: []].append(
                    AnalyticsGoalPoint(date: group.date, value: sdvxValue(records, goal: goal))
                )
            }
        }
        return result
    }

    static func sdvxValue(_ records: [SDVXSongRecord], goal: AnalyticsGoal) -> Double {
        switch goal.kind {
        case .rating:
            return SDVXAnalyticsModel.volforce(of: records)
        case .clearCount:
            let ranking = SDVXClearType.sortedStringsWithoutNoPlay
            return Double(countAtOrAbove(records, ranking: ranking, goal: goal,
                                         value: \.clearType) {
                Int(Double($0.level) ?? 0.0)
            })
        case .gradeCount:
            return Double(countAtOrAbove(records, ranking: SDVXGrade.sortedStrings, goal: goal,
                                         value: \.grade) {
                Int(Double($0.level) ?? 0.0)
            })
        }
    }

    // MARK: - DanceDanceRevolution

    static func ddrHistories(for goals: [AnalyticsGoal], version: DDRVersion) async -> [UUID: [AnalyticsGoalPoint]] {
        let reader = DDRReader()
        let groups = await reader.importGroups(for: version).reversed()
        var result: [UUID: [AnalyticsGoalPoint]] = [:]
        for group in groups {
            let records = await reader.songRecords(for: group.id)
            guard !records.isEmpty else { continue }
            for goal in goals {
                let styled = records.filter { $0.styleEnum.rawValue == goal.playStyle }
                guard !styled.isEmpty else { continue }
                result[goal.id, default: []].append(
                    AnalyticsGoalPoint(date: group.date, value: ddrValue(styled, goal: goal))
                )
            }
        }
        return result
    }

    static func ddrValue(_ records: [DDRSongRecord], goal: AnalyticsGoal) -> Double {
        switch goal.kind {
        case .rating:
            return Double(records.map(\.flareSkill).sorted(by: >).prefix(90).reduce(0, +))
        case .clearCount:
            return Double(countAtOrAbove(records, ranking: DDRSongRecord.clearLampOrder, goal: goal,
                                         value: \.clearKind) { $0.level })
        case .gradeCount:
            return Double(countAtOrAbove(records, ranking: DDRSongRecord.rankOrder, goal: goal,
                                         value: \.rank) { $0.level })
        }
    }

    // MARK: - Helpers

    static func countAtOrAbove<Record>(
        _ records: [Record],
        ranking: [String],
        goal: AnalyticsGoal,
        value: KeyPath<Record, String>,
        levelOf: (Record) -> Int
    ) -> Int {
        guard let thresholdRank = ranking.firstIndex(of: goal.threshold) else { return 0 }
        return records.filter { record in
            guard goal.level == 0 || levelOf(record) == goal.level,
                  let rank = ranking.firstIndex(of: record[keyPath: value]) else { return false }
            return rank <= thresholdRank
        }.count
    }
}
