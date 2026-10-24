package com.tsubuzaki.djdxgo.data.analytics

import com.tsubuzaki.djdxgo.data.compact
import com.tsubuzaki.djdxgo.data.ddr.DDRClearLamp
import com.tsubuzaki.djdxgo.data.ddr.DDRDifficulty
import com.tsubuzaki.djdxgo.data.ddr.DDRRank
import com.tsubuzaki.djdxgo.data.ddr.DDRSongRecord
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordClearType
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordDifficulty
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordGrade
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordSongRecord
import com.tsubuzaki.djdxgo.data.sdvx.SDVXClearType
import com.tsubuzaki.djdxgo.data.sdvx.SDVXDifficulty
import com.tsubuzaki.djdxgo.data.sdvx.SDVXGrade
import com.tsubuzaki.djdxgo.data.sdvx.SDVXSongRecord
import java.util.Locale
import kotlin.math.floor

data class ChartNewEntry(
    val title: String,
    val level: String,
    val difficulty: String,
    val previousValue: String,
    val newValue: String,
    val previousScore: Int = 0,
    val newScore: Int = 0,
    val previousGrade: String = "",
    val newGrade: String = ""
)

data class ChartAnalyticsData(
    val clearTypePerDifficulty: Map<String, Map<String, Int>> = emptyMap(),
    val gradePerDifficulty: Map<String, Map<String, Int>> = emptyMap(),
    val clearTypePerLevel: Map<Int, Map<String, Int>> = emptyMap(),
    val gradePerLevel: Map<Int, Map<String, Int>> = emptyMap(),
    val newHighScores: List<ChartNewEntry> = emptyList(),
    val newClears: Map<String, List<ChartNewEntry>> = emptyMap(),
    val newGrades: Map<String, List<ChartNewEntry>> = emptyMap()
) {
    fun totalClearCounts(keys: List<String>): List<Pair<String, Int>> =
        keys.map { key -> key to clearTypePerDifficulty.values.sumOf { it[key] ?: 0 } }

    fun totalGradeCounts(keys: List<String>): List<Pair<String, Int>> =
        keys.map { key -> key to gradePerDifficulty.values.sumOf { it[key] ?: 0 } }
}

data class SDVXFilterOptions(
    val difficulties: Set<String> = emptySet(),
    val levelBuckets: Set<String> = emptySet(),
    val clearTypes: Set<String> = emptySet(),
    val grades: Set<String> = emptySet()
) {
    fun matches(record: SDVXSongRecord): Boolean =
        (difficulties.isEmpty() || record.difficulty in difficulties) &&
            (levelBuckets.isEmpty() || sdvxLevelBucket(record.level) in levelBuckets) &&
            (clearTypes.isEmpty() || record.clearType in clearTypes) &&
            (grades.isEmpty() || record.grade in grades)
}

fun sdvxLevelBucket(level: String): String {
    val value = level.toDoubleOrNull() ?: 0.0
    return String.format(Locale.ROOT, "%.1f", floor(value * 2.0) / 2.0)
}

data class PolarisChordFilterOptions(
    val difficulties: Set<String> = emptySet(),
    val levels: Set<String> = emptySet(),
    val clearTypes: Set<String> = emptySet(),
    val grades: Set<String> = emptySet()
) {
    fun matches(record: PolarisChordSongRecord): Boolean =
        (difficulties.isEmpty() || record.difficulty in difficulties) &&
            (levels.isEmpty() || record.level in levels) &&
            (clearTypes.isEmpty() || record.clearType in clearTypes) &&
            (grades.isEmpty() || record.grade in grades)
}

data class DDRFilterOptions(
    val onlyPlayedCharts: Boolean = true,
    val difficulties: Set<String> = emptySet(),
    val levels: Set<String> = emptySet(),
    val clearLamps: Set<String> = emptySet(),
    val ranks: Set<String> = emptySet()
) {
    fun matches(record: DDRSongRecord): Boolean =
        (!onlyPlayedCharts || record.hasScore) &&
            (difficulties.isEmpty() || record.difficulty in difficulties) &&
            (levels.isEmpty() || record.level.toString() in levels) &&
            (clearLamps.isEmpty() || record.clearKind in clearLamps) &&
            (ranks.isEmpty() || record.rank in ranks)
}

val DDRSongRecord.hasScore: Boolean
    get() = score > 0 || clearKind.isNotEmpty()

object ChartAnalytics {

    val sdvxClearKeys = SDVXClearType.sorted.filter { it != SDVXClearType.NO_PLAY }.map { it.value }
    val sdvxGradeKeys = SDVXGrade.sorted.map { it.value }
    val sdvxTrackedClearTypes = listOf(
        SDVXClearType.COMPLETE, SDVXClearType.EXCESSIVE_COMPLETE,
        SDVXClearType.ULTIMATE_CHAIN, SDVXClearType.PERFECT_ULTIMATE_CHAIN
    ).map { it.value }
    val sdvxTrackedGrades = listOf(
        SDVXGrade.S, SDVXGrade.AAA_PLUS, SDVXGrade.AAA, SDVXGrade.AA_PLUS,
        SDVXGrade.AA, SDVXGrade.A_PLUS, SDVXGrade.A
    ).map { it.value }

    val polarisChordClearKeys = PolarisChordClearType.sorted
        .filter { it != PolarisChordClearType.NO_PLAY }.map { it.value }
    val polarisChordGradeKeys = PolarisChordGrade.sorted.map { it.value }
    val polarisChordTrackedClearTypes = listOf(
        PolarisChordClearType.SUCCESS, PolarisChordClearType.FULL_COMBO, PolarisChordClearType.ALL_PERFECT
    ).map { it.value }
    val polarisChordTrackedGrades = listOf(
        PolarisChordGrade.SSS_PLUS, PolarisChordGrade.SSS, PolarisChordGrade.SS, PolarisChordGrade.S
    ).map { it.value }

    const val DDR_NO_CLEAR = "noclear"
    val ddrClearKeys = DDRClearLamp.order + DDR_NO_CLEAR
    val ddrRankKeys = DDRRank.order

    private class Counter(private val keys: List<String>) {
        val values = LinkedHashMap<Any, MutableMap<String, Int>>()

        fun add(group: Any, key: String) {
            if (key !in keys) return
            values.getOrPut(group) { keys.associateWith { 0 }.toMutableMap() }.merge(key, 1, Int::plus)
        }

        fun ensure(group: Any) {
            values.getOrPut(group) { keys.associateWith { 0 }.toMutableMap() }
        }

        @Suppress("UNCHECKED_CAST")
        fun <K> result(): Map<K, Map<String, Int>> = values as Map<K, Map<String, Int>>
    }

    fun sdvx(
        latestRecords: List<SDVXSongRecord>,
        previousRecords: List<SDVXSongRecord>?,
        filters: SDVXFilterOptions
    ): ChartAnalyticsData {
        val records = latestRecords.filter(filters::matches)
        val clearByDifficulty = Counter(sdvxClearKeys)
        val gradeByDifficulty = Counter(sdvxGradeKeys)
        val clearByLevel = Counter(sdvxClearKeys)
        records.forEach { record ->
            val difficulty = SDVXDifficulty.fromValue(record.difficulty)
            val category = if (difficulty?.isInfiniteTier == true) {
                SDVXDifficulty.INFINITE.value
            } else {
                record.difficulty
            }
            clearByDifficulty.ensure(category)
            gradeByDifficulty.ensure(category)
            clearByDifficulty.add(category, record.clearType)
            gradeByDifficulty.add(category, record.grade)
            val level = record.level.toDoubleOrNull()?.toInt() ?: 0
            if (level > 0) {
                clearByLevel.ensure(level)
                clearByLevel.add(level, record.clearType)
            }
        }
        val lastPlay = previousRecords?.let { previous ->
            newEntries(
                latest = records,
                previous = previous,
                key = { "${it.title.compact}|${it.difficulty}" },
                title = { it.title },
                level = { it.level },
                difficulty = { it.difficulty },
                clearType = { it.clearType },
                grade = { it.grade },
                score = { it.highScore },
                noPlay = SDVXClearType.NO_PLAY.value,
                noGrade = SDVXGrade.NONE.value,
                trackedClearTypes = sdvxTrackedClearTypes,
                trackedGrades = sdvxTrackedGrades
            )
        }
        return ChartAnalyticsData(
            clearTypePerDifficulty = clearByDifficulty.result(),
            gradePerDifficulty = gradeByDifficulty.result(),
            clearTypePerLevel = clearByLevel.result(),
            newHighScores = lastPlay?.first.orEmpty(),
            newClears = lastPlay?.second.orEmpty(),
            newGrades = lastPlay?.third.orEmpty()
        )
    }

    fun polarisChord(
        latestRecords: List<PolarisChordSongRecord>,
        previousRecords: List<PolarisChordSongRecord>?,
        filters: PolarisChordFilterOptions
    ): ChartAnalyticsData {
        val records = latestRecords.filter(filters::matches)
        val clearByDifficulty = Counter(polarisChordClearKeys)
        val gradeByDifficulty = Counter(polarisChordGradeKeys)
        val clearByLevel = Counter(polarisChordClearKeys)
        records.forEach { record ->
            clearByDifficulty.ensure(record.difficulty)
            gradeByDifficulty.ensure(record.difficulty)
            clearByDifficulty.add(record.difficulty, record.clearType)
            gradeByDifficulty.add(record.difficulty, record.grade)
            val level = record.level.toDoubleOrNull()?.toInt() ?: 0
            if (level > 0) {
                clearByLevel.ensure(level)
                clearByLevel.add(level, record.clearType)
            }
        }
        val lastPlay = previousRecords?.let { previous ->
            newEntries(
                latest = records,
                previous = previous,
                key = { "${it.title.compact}|${it.difficulty}" },
                title = { it.title },
                level = { it.level },
                difficulty = { it.difficulty },
                clearType = { it.clearType },
                grade = { it.grade },
                score = { it.score },
                noPlay = PolarisChordClearType.NO_PLAY.value,
                noGrade = PolarisChordGrade.NONE.value,
                trackedClearTypes = polarisChordTrackedClearTypes,
                trackedGrades = polarisChordTrackedGrades
            )
        }
        return ChartAnalyticsData(
            clearTypePerDifficulty = clearByDifficulty.result(),
            gradePerDifficulty = gradeByDifficulty.result(),
            clearTypePerLevel = clearByLevel.result(),
            newHighScores = lastPlay?.first.orEmpty(),
            newClears = lastPlay?.second.orEmpty(),
            newGrades = lastPlay?.third.orEmpty()
        )
    }

    fun ddr(records: List<DDRSongRecord>, filters: DDRFilterOptions): ChartAnalyticsData {
        val clearByDifficulty = Counter(ddrClearKeys)
        val rankByDifficulty = Counter(ddrRankKeys)
        val clearByLevel = Counter(ddrClearKeys)
        val rankByLevel = Counter(ddrRankKeys)
        records.filter(filters::matches).forEach { record ->
            clearByDifficulty.ensure(record.difficulty)
            rankByDifficulty.ensure(record.difficulty)
            val clearBucket = when {
                record.clearKind in DDRClearLamp.order -> record.clearKind
                record.hasScore -> DDR_NO_CLEAR
                else -> null
            }
            clearBucket?.let { clearByDifficulty.add(record.difficulty, it) }
            if (record.rank in ddrRankKeys) {
                rankByDifficulty.add(record.difficulty, record.rank)
                if (record.level > 0) {
                    rankByLevel.ensure(record.level)
                    rankByLevel.add(record.level, record.rank)
                }
            }
            if (record.level > 0 && clearBucket != null) {
                clearByLevel.ensure(record.level)
                clearByLevel.add(record.level, clearBucket)
            }
        }
        return ChartAnalyticsData(
            clearTypePerDifficulty = clearByDifficulty.result(),
            gradePerDifficulty = rankByDifficulty.result(),
            clearTypePerLevel = clearByLevel.result(),
            gradePerLevel = rankByLevel.result()
        )
    }

    val ddrDifficultyOrder: List<String> = DDRDifficulty.entries.map { it.value }
    val polarisChordDifficultyOrder: List<String> = PolarisChordDifficulty.entries.map { it.value }
    val sdvxDifficultyOrder: List<String> = SDVXDifficulty.sorted.map { it.value }

    private fun <T> newEntries(
        latest: List<T>,
        previous: List<T>,
        key: (T) -> String,
        title: (T) -> String,
        level: (T) -> String,
        difficulty: (T) -> String,
        clearType: (T) -> String,
        grade: (T) -> String,
        score: (T) -> Int,
        noPlay: String,
        noGrade: String,
        trackedClearTypes: List<String>,
        trackedGrades: List<String>
    ): Triple<List<ChartNewEntry>, Map<String, List<ChartNewEntry>>, Map<String, List<ChartNewEntry>>> {
        val previousByKey = previous.associateBy(key)
        val highScores = mutableListOf<ChartNewEntry>()
        val clears = trackedClearTypes.associateWith { mutableListOf<ChartNewEntry>() }
        val grades = trackedGrades.associateWith { mutableListOf<ChartNewEntry>() }
        for (record in latest) {
            val previousRecord = previousByKey[key(record)]
            val previousClearType = previousRecord?.let(clearType) ?: noPlay
            val previousGrade = previousRecord?.let(grade) ?: noGrade
            val previousScore = previousRecord?.let(score) ?: 0
            val base = ChartNewEntry(
                title = title(record),
                level = level(record),
                difficulty = difficulty(record),
                previousValue = "",
                newValue = ""
            )
            val recordClearType = clearType(record)
            if (recordClearType in trackedClearTypes && recordClearType != previousClearType) {
                clears.getValue(recordClearType)
                    .add(base.copy(previousValue = previousClearType, newValue = recordClearType))
            }
            val recordGrade = grade(record)
            if (recordGrade in trackedGrades && recordGrade != previousGrade) {
                grades.getValue(recordGrade)
                    .add(base.copy(previousValue = previousGrade, newValue = recordGrade))
            }
            val recordScore = score(record)
            if (recordScore > previousScore) {
                highScores.add(
                    base.copy(
                        previousScore = previousScore,
                        newScore = recordScore,
                        previousGrade = previousGrade,
                        newGrade = recordGrade
                    )
                )
            }
        }
        return Triple(highScores, clears, grades)
    }
}
