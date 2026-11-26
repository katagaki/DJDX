package com.tsubuzaki.djdxgo.data.ddr

import com.tsubuzaki.djdxgo.data.analytics.RatingPool

data class DDRFlareSkillRow(
    val date: Long,
    val title: String,
    val flareSkill: Int
)

object DDRFlareSkill {
    const val CHART_LIMIT = 30

    private val baseValues = listOf(
        0, 145, 155, 170, 185, 205, 230, 255, 290, 335, 400,
        465, 510, 545, 575, 600, 620, 635, 650, 665
    )
    private val rankMultipliers = listOf(100, 106, 112, 118, 124, 130, 136, 142, 148, 154, 160)
    private val rankLabels = listOf("0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "EX")

    val rankRange: IntRange get() = rankMultipliers.indices

    fun total(records: List<DDRSongRecord>, version: (DDRSongRecord) -> Int): Int =
        sumTop(records.map { it.flareSkill to category(version(it)) })

    fun totalForRows(rows: List<DDRFlareSkillRow>, version: (DDRFlareSkillRow) -> Int): Int =
        sumTop(rows.map { it.flareSkill to category(version(it)) })

    fun category(version: Int): Int = when (version) {
        in 1..11 -> 1
        in 12..19 -> 2
        else -> 3
    }

    private fun sumTop(skills: List<Pair<Int, Int>>): Int =
        skills.groupBy { it.second }.values.sumOf { group -> RatingPool(group.map { it.first }, CHART_LIMIT).total }

    fun rankLabel(rank: Int): String = "FLARE ${rankLabels.getOrElse(rank) { "" }}"

    fun skill(level: Int, rank: Int): Int {
        if (level !in baseValues.indices || rank !in rankMultipliers.indices) return 0
        return baseValues[level] * rankMultipliers[rank] / 100
    }

    fun isRated(level: Int): Boolean = level > 0 && level in baseValues.indices

    fun rank(level: Int, flareSkill: Int): Int? {
        if (flareSkill <= 0 || !isRated(level)) return null
        return rankMultipliers.indices.minByOrNull { kotlin.math.abs(skill(level, it) - flareSkill) }
    }
}
