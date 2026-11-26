package com.tsubuzaki.djdxgo.data.ddr

object DDRFlareSkill {

    fun total(records: List<DDRSongRecord>, version: (DDRSongRecord) -> Int): Int =
        records.filter { it.flareSkill > 0 }
            .groupBy { category(version(it)) }
            .values
            .sumOf { group -> group.map { it.flareSkill }.sortedDescending().take(30).sum() }

    fun category(version: Int): Int = when {
        version in 1..11 -> 1
        version in 12..16 -> 2
        version >= 17 -> 3
        else -> 0
    }
}
