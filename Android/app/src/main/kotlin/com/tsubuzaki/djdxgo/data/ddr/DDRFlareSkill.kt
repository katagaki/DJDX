package com.tsubuzaki.djdxgo.data.ddr

data class DDRFlareSkillRow(
    val date: Long,
    val title: String,
    val flareSkill: Int
)

object DDRFlareSkill {

    fun total(records: List<DDRSongRecord>, version: (DDRSongRecord) -> Int): Int =
        sumTop(records.filter { it.flareSkill > 0 }.map { it.flareSkill to category(version(it)) })

    fun totalForRows(rows: List<DDRFlareSkillRow>, version: (DDRFlareSkillRow) -> Int): Int =
        sumTop(rows.filter { it.flareSkill > 0 }.map { it.flareSkill to category(version(it)) })

    fun category(version: Int): Int = when (version) {
        in 1..11 -> 1
        in 12..19 -> 2
        else -> 3
    }

    private fun sumTop(skills: List<Pair<Int, Int>>): Int =
        skills.groupBy { it.second }.values.sumOf { group ->
            group.map { it.first }.sortedDescending().take(30).sum()
        }
}
