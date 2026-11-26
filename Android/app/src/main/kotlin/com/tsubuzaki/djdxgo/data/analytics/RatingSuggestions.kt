package com.tsubuzaki.djdxgo.data.analytics

import com.tsubuzaki.djdxgo.data.compact
import com.tsubuzaki.djdxgo.data.ddrCompact
import com.tsubuzaki.djdxgo.data.ddr.DDRSongRecord
import com.tsubuzaki.djdxgo.data.external.IIDXSong
import com.tsubuzaki.djdxgo.data.iidx.IIDXClearType
import com.tsubuzaki.djdxgo.data.iidx.IIDXDJLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import com.tsubuzaki.djdxgo.data.iidx.IIDXSongRecord
import com.tsubuzaki.djdxgo.data.sdvx.SDVXClearType
import com.tsubuzaki.djdxgo.data.sdvx.SDVXGrade
import com.tsubuzaki.djdxgo.data.sdvx.SDVXSongRecord
import com.tsubuzaki.djdxgo.ui.iidx.noteCount
import java.util.Locale
import kotlin.math.floor

class RatingPool(values: List<Int>, private val limit: Int) {
    private val count = values.size
    private val cutoff: Int
    val total: Int

    init {
        val sorted = values.sortedDescending()
        total = sorted.take(limit).sum()
        cutoff = if (sorted.size >= limit) sorted[limit - 1] else 0
    }

    fun gain(oldValue: Int, newValue: Int): Int = when {
        newValue <= oldValue -> 0
        count < limit || oldValue >= cutoff -> newValue - oldValue
        else -> maxOf(0, newValue - cutoff)
    }
}

data class ChartSuggestion(
    val title: String,
    val difficulty: String,
    val level: String,
    val current: String,
    val target: String,
    val gain: Int,
    val gainText: String,
    val pointsNeeded: Int? = null,
    val currentValue: Int = 0,
    val targetValue: Int = 0
)

object SDVXVolforce {
    private const val CHART_LIMIT = 50

    private val gradeThresholds = listOf(
        SDVXGrade.C to 6_500_000, SDVXGrade.B to 7_500_000, SDVXGrade.A to 8_700_000,
        SDVXGrade.A_PLUS to 9_000_000, SDVXGrade.AA to 9_300_000, SDVXGrade.AA_PLUS to 9_500_000,
        SDVXGrade.AAA to 9_700_000, SDVXGrade.AAA_PLUS to 9_800_000, SDVXGrade.S to 9_900_000
    )

    private val gradeCoefficients = mapOf(
        SDVXGrade.S to 105, SDVXGrade.AAA_PLUS to 102, SDVXGrade.AAA to 100, SDVXGrade.AA_PLUS to 97,
        SDVXGrade.AA to 94, SDVXGrade.A_PLUS to 91, SDVXGrade.A to 88, SDVXGrade.B to 85,
        SDVXGrade.C to 82, SDVXGrade.D to 80
    )

    private val clearCoefficients = mapOf(
        SDVXClearType.PERFECT_ULTIMATE_CHAIN.value to 110,
        SDVXClearType.ULTIMATE_CHAIN.value to 106,
        SDVXClearType.EXCESSIVE_COMPLETE.value to 102,
        SDVXClearType.COMPLETE.value to 100,
        SDVXClearType.PLAYED.value to 50
    )

    fun grade(score: Int): SDVXGrade = when {
        score <= 0 -> SDVXGrade.NONE
        else -> gradeThresholds.lastOrNull { score >= it.second }?.first ?: SDVXGrade.D
    }

    fun force(level: Double, score: Int, clearType: String): Int {
        if (level <= 0.0 || score <= 0) return 0
        val value = level * score * (gradeCoefficients[grade(score)] ?: 0) *
            (clearCoefficients[clearType] ?: 0) * 20.0 / 10_000_000.0 / 10_000.0
        return floor(value + 1e-9).toInt()
    }

    fun force(record: SDVXSongRecord): Int =
        force(record.level.toDoubleOrNull() ?: 0.0, record.highScore, record.clearType)

    fun total(records: List<SDVXSongRecord>): Double = RatingPool(records.map(::force), CHART_LIMIT).total / 1000.0

    fun gainText(gain: Int): String = String.format(Locale.ROOT, "+%.3f", gain / 1000.0)

    fun suggestions(allRecords: List<SDVXSongRecord>, candidates: List<SDVXSongRecord>): List<ChartSuggestion> {
        val pool = RatingPool(allRecords.map(::force), CHART_LIMIT)
        return candidates.mapNotNull { record ->
            val level = record.level.toDoubleOrNull() ?: 0.0
            if (level <= 0.0 || record.highScore <= 0) return@mapNotNull null
            val target = gradeThresholds.firstOrNull { it.second > record.highScore } ?: return@mapNotNull null
            val clearType = if (record.clearType == SDVXClearType.NO_PLAY.value) {
                SDVXClearType.PLAYED.value
            } else {
                record.clearType
            }
            val gain = pool.gain(
                force(level, record.highScore, record.clearType),
                force(level, target.second, clearType)
            )
            if (gain <= 0) return@mapNotNull null
            ChartSuggestion(
                title = record.title,
                difficulty = record.difficulty,
                level = record.level,
                current = grade(record.highScore).value,
                target = target.first.value,
                gain = gain,
                gainText = gainText(gain),
                pointsNeeded = target.second - record.highScore
            )
        }.sortedWith(compareByDescending<ChartSuggestion> { it.gain }.thenBy { it.pointsNeeded })
    }
}

object DDRFlareSkill {
    private const val CHART_LIMIT = 30
    private const val WORLD_VERSION = 20

    private val baseValues = listOf(
        0, 145, 155, 170, 185, 205, 230, 255, 290, 335, 400,
        465, 510, 545, 575, 600, 620, 635, 650, 665
    )
    private val rankMultipliers = listOf(100, 106, 112, 118, 124, 130, 136, 142, 148, 154, 160)
    private val rankLabels = listOf("0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "EX")

    fun rankLabel(rank: Int): String = "FLARE ${rankLabels.getOrElse(rank) { "" }}"

    fun skill(level: Int, rank: Int): Int {
        if (level !in baseValues.indices || rank !in rankMultipliers.indices) return 0
        return baseValues[level] * rankMultipliers[rank] / 100
    }

    fun rank(level: Int, flareSkill: Int): Int? {
        if (flareSkill <= 0 || level <= 0 || level !in baseValues.indices) return null
        return rankMultipliers.indices.minByOrNull { kotlin.math.abs(skill(level, it) - flareSkill) }
    }

    fun category(version: Int): Int = when (version) {
        in 1..13 -> 1
        in 14..19 -> 2
        in WORLD_VERSION..Int.MAX_VALUE -> 3
        else -> 0
    }

    fun suggestions(
        allRecords: List<DDRSongRecord>,
        candidates: List<DDRSongRecord>,
        versions: Map<String, Int>
    ): List<ChartSuggestion> {
        fun categoryOf(record: DDRSongRecord) = category(versions[record.title.ddrCompact] ?: 0)
        val pools = allRecords.groupBy(::categoryOf)
            .mapValues { (_, records) -> RatingPool(records.map { it.flareSkill }, CHART_LIMIT) }
        return candidates.mapNotNull { record ->
            if (record.level <= 0 || record.level !in baseValues.indices) return@mapNotNull null
            val pool = pools[categoryOf(record)] ?: return@mapNotNull null
            val currentRank = rank(record.level, record.flareSkill)
            val targetRank = (currentRank ?: -1) + 1
            if (targetRank !in rankMultipliers.indices) return@mapNotNull null
            val targetSkill = skill(record.level, targetRank)
            val gain = pool.gain(record.flareSkill, targetSkill)
            if (gain <= 0) return@mapNotNull null
            ChartSuggestion(
                title = record.title,
                difficulty = record.difficulty,
                level = record.level.toString(),
                current = currentRank?.let(::rankLabel) ?: "---",
                target = rankLabel(targetRank),
                gain = gain,
                gainText = "+$gain",
                currentValue = record.flareSkill,
                targetValue = targetSkill
            )
        }.sortedWith(compareByDescending<ChartSuggestion> { it.gain }.thenBy { it.level.toIntOrNull() ?: 0 })
    }
}

data class IIDXDJLevelSuggestion(
    val title: String,
    val level: IIDXLevel,
    val difficulty: Int,
    val score: Int,
    val currentDJLevel: String,
    val targetDJLevel: String,
    val targetScore: Int
) {
    val pointsNeeded: Int
        get() = targetScore - score
}

data class IIDXClearLampSuggestion(
    val title: String,
    val level: IIDXLevel,
    val difficulty: Int,
    val score: Int,
    val clearType: String
)

object IIDXSuggestions {
    private val djLevelThresholds = listOf(
        IIDXDJLevel.E, IIDXDJLevel.D, IIDXDJLevel.C, IIDXDJLevel.B,
        IIDXDJLevel.A, IIDXDJLevel.AA, IIDXDJLevel.AAA
    )

    val targetClearTypes = listOf(
        IIDXClearType.ASSIST_CLEAR, IIDXClearType.EASY_CLEAR, IIDXClearType.CLEAR,
        IIDXClearType.HARD_CLEAR, IIDXClearType.EX_HARD_CLEAR, IIDXClearType.FULL_COMBO_CLEAR
    )

    fun clearTypeBefore(target: IIDXClearType): IIDXClearType? =
        IIDXClearType.ascending.indexOf(target).takeIf { it > 0 }?.let { IIDXClearType.ascending[it - 1] }

    fun clearLampSuggestions(
        candidates: List<IIDXClearLampSuggestion>,
        target: IIDXClearType
    ): List<IIDXClearLampSuggestion> {
        val previous = clearTypeBefore(target) ?: return emptyList()
        return candidates.filter { it.clearType == previous.value }
    }

    private fun threshold(index: Int, maxScore: Int): Int = (maxScore * (index + 2) + 8) / 9

    fun compute(
        records: List<IIDXSongRecord>,
        songs: List<IIDXSong>,
        playType: IIDXPlayType,
        filters: IIDXFilterOptions
    ): Pair<List<IIDXDJLevelSuggestion>, List<IIDXClearLampSuggestion>> {
        val songsByTitle = songs.associateBy { it.titleCompact }
        val djLevels = mutableListOf<IIDXDJLevelSuggestion>()
        val clearLamps = mutableListOf<IIDXClearLampSuggestion>()
        for (record in records) {
            if (filters.versions.isNotEmpty() && record.version !in filters.versions) continue
            val song = songsByTitle[record.title.compact]
            for (level in IIDXLevel.entries) {
                val score = record.slot(level)
                if (score.difficulty <= 0 || !filters.matches(level, score)) continue
                if (score.clearType != IIDXClearType.NO_PLAY.value) {
                    clearLamps.add(
                        IIDXClearLampSuggestion(record.title, level, score.difficulty, score.score, score.clearType)
                    )
                }
                val noteCount = song?.noteCount(playType, level) ?: continue
                if (score.score <= 0 || noteCount <= 0) continue
                val maxScore = noteCount * 2
                val targetIndex = djLevelThresholds.indices
                    .firstOrNull { threshold(it, maxScore) > score.score } ?: continue
                djLevels.add(
                    IIDXDJLevelSuggestion(
                        title = record.title,
                        level = level,
                        difficulty = score.difficulty,
                        score = score.score,
                        currentDJLevel = if (targetIndex > 0) djLevelThresholds[targetIndex - 1].value else "F",
                        targetDJLevel = djLevelThresholds[targetIndex].value,
                        targetScore = threshold(targetIndex, maxScore)
                    )
                )
            }
        }
        return Pair(
            djLevels.sortedWith(compareBy<IIDXDJLevelSuggestion> { it.pointsNeeded }.thenByDescending { it.difficulty }),
            clearLamps.sortedWith(
                compareByDescending<IIDXClearLampSuggestion> { it.difficulty }.thenByDescending { it.score }
            )
        )
    }
}
