import Foundation

struct DDRFlareSkillSuggestion: Identifiable {
    let id = UUID()
    let record: DDRSongRecord
    let currentFlareRank: Int?
    let targetFlareRank: Int
    let currentFlareSkill: Int
    let targetFlareSkill: Int
    let flareSkillGain: Int
}

extension DDRFlareSkill {

    static let baseValues: [Int] = [
        0, 145, 155, 170, 185, 205, 230, 255, 290, 335, 400,
        465, 510, 545, 575, 600, 620, 635, 650, 665
    ]

    static let rankMultipliers: [Int] = [100, 106, 112, 118, 124, 130, 136, 142, 148, 154, 160]

    static func rankLabel(_ rank: Int) -> String {
        let labels = ["0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "EX"]
        return labels.indices.contains(rank) ? labels[rank] : ""
    }

    static func skill(level: Int, rank: Int) -> Int {
        guard baseValues.indices.contains(level), rankMultipliers.indices.contains(rank) else { return 0 }
        return baseValues[level] * rankMultipliers[rank] / 100
    }

    static func rank(level: Int, skill flareSkill: Int) -> Int? {
        guard flareSkill > 0, baseValues.indices.contains(level), level > 0 else { return nil }
        return rankMultipliers.indices.min { lhs, rhs in
            abs(skill(level: level, rank: lhs) - flareSkill) < abs(skill(level: level, rank: rhs) - flareSkill)
        }
    }

    static func suggestions(allRecords: [DDRSongRecord],
                            candidates: [DDRSongRecord]) -> [DDRFlareSkillSuggestion] {
        let pools = Dictionary(grouping: allRecords) { category(for: $0.version) }
            .mapValues { RatingPool(values: $0.map(\.flareSkill), limit: chartLimit) }
        return candidates.compactMap { record -> DDRFlareSkillSuggestion? in
            guard record.level > 0, baseValues.indices.contains(record.level),
                  let pool = pools[category(for: record.version)] else { return nil }
            let currentRank = rank(level: record.level, skill: record.flareSkill)
            let targetRank = (currentRank ?? -1) + 1
            guard rankMultipliers.indices.contains(targetRank) else { return nil }
            let targetSkill = skill(level: record.level, rank: targetRank)
            let gain = pool.gain(replacing: record.flareSkill, with: targetSkill)
            guard gain > 0 else { return nil }
            return DDRFlareSkillSuggestion(
                record: record,
                currentFlareRank: currentRank,
                targetFlareRank: targetRank,
                currentFlareSkill: record.flareSkill,
                targetFlareSkill: targetSkill,
                flareSkillGain: gain
            )
        }
        .sorted {
            if $0.flareSkillGain != $1.flareSkillGain { return $0.flareSkillGain > $1.flareSkillGain }
            return $0.record.level < $1.record.level
        }
    }
}
