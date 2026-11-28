package com.tsubuzaki.djdxgo.data.analytics

import com.tsubuzaki.djdxgo.data.compact
import com.tsubuzaki.djdxgo.data.ddrCompact
import com.tsubuzaki.djdxgo.data.ddr.DDRFlareSkill
import com.tsubuzaki.djdxgo.data.ddr.DDRSongRecord
import com.tsubuzaki.djdxgo.data.external.IIDXSong
import com.tsubuzaki.djdxgo.data.iidx.IIDXClearType
import com.tsubuzaki.djdxgo.data.iidx.IIDXDJLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import com.tsubuzaki.djdxgo.data.iidx.IIDXSongRecord
import com.tsubuzaki.djdxgo.data.sdvx.SDVXClearType
import com.tsubuzaki.djdxgo.data.sdvx.SDVXSongRecord
import com.tsubuzaki.djdxgo.data.sdvx.SDVXVolforce
import com.tsubuzaki.djdxgo.ui.iidx.noteCount
import java.util.Locale

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

fun SDVXVolforce.gainText(gain: Int): String = String.format(Locale.ROOT, "+%.3f", gain / 1000.0)

fun SDVXVolforce.suggestions(allRecords: List<SDVXSongRecord>, candidates: List<SDVXSongRecord>): List<ChartSuggestion> {
    val pool = RatingPool(allRecords.map(::chartForce), SDVXVolforce.CHART_LIMIT)
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

fun DDRFlareSkill.suggestions(
    allRecords: List<DDRSongRecord>,
    candidates: List<DDRSongRecord>,
    versions: Map<String, Int>
): List<ChartSuggestion> {
    fun categoryOf(record: DDRSongRecord) = category(versions[record.title.ddrCompact] ?: 0)
    val pools = allRecords.groupBy(::categoryOf)
        .mapValues { (_, records) -> RatingPool(records.map { it.flareSkill }, DDRFlareSkill.CHART_LIMIT) }
    return candidates.mapNotNull { record ->
        if (!isRated(record.level)) return@mapNotNull null
        val pool = pools[categoryOf(record)] ?: return@mapNotNull null
        val currentRank = rank(record.level, record.flareSkill)
        val targetRank = (currentRank ?: -1) + 1
        if (targetRank !in rankRange) return@mapNotNull null
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
    val clearType: String,
    val scoreRate: Float? = null,
    val missCount: Int = 0
) {
    val missSortKey: Int
        get() = if (missCount > 0) missCount else Int.MAX_VALUE
}

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
        val filtered = candidates.filter { it.clearType == previous.value }
        if (target != IIDXClearType.FULL_COMBO_CLEAR) return filtered
        return filtered.sortedWith(
            compareBy<IIDXClearLampSuggestion> { it.missSortKey }.thenByDescending { it.scoreRate ?: -1f }
        )
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
                val noteCount = song?.noteCount(playType, level) ?: 0
                if (score.clearType != IIDXClearType.NO_PLAY.value) {
                    clearLamps.add(
                        IIDXClearLampSuggestion(
                            title = record.title,
                            level = level,
                            difficulty = score.difficulty,
                            score = score.score,
                            clearType = score.clearType,
                            scoreRate = if (noteCount > 0) score.score.toFloat() / (noteCount * 2) else null,
                            missCount = score.missCount
                        )
                    )
                }
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
                compareByDescending<IIDXClearLampSuggestion> { it.scoreRate ?: -1f }
                    .thenBy { it.missSortKey }
                    .thenByDescending { it.difficulty }
            )
        )
    }
}
