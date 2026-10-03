package com.tsubuzaki.djdxgo.data.analytics

import androidx.sqlite.db.SimpleSQLiteQuery
import com.tsubuzaki.djdxgo.data.compact
import com.tsubuzaki.djdxgo.data.iidx.IIDXClearType
import com.tsubuzaki.djdxgo.data.iidx.IIDXDJLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXDao
import com.tsubuzaki.djdxgo.data.iidx.IIDXImportGroup
import com.tsubuzaki.djdxgo.data.iidx.IIDXLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXLevelAggregate
import com.tsubuzaki.djdxgo.data.iidx.IIDXLevelScore
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import com.tsubuzaki.djdxgo.data.iidx.IIDXSongRecord
import com.tsubuzaki.djdxgo.data.iidx.IIDXTowerEntry
import com.tsubuzaki.djdxgo.data.iidx.IIDXVersionInfo

data class IIDXFilterOptions(
    val onlyPlayDataWithScores: Boolean = true,
    val levels: Set<String> = emptySet(),
    val difficulties: Set<String> = emptySet(),
    val clearTypes: Set<String> = emptySet(),
    val djLevels: Set<String> = emptySet(),
    val versions: Set<String> = emptySet()
) {
    fun matches(level: IIDXLevel, score: IIDXLevelScore): Boolean =
        (levels.isEmpty() || level.code in levels) &&
            (difficulties.isEmpty() || score.difficulty.toString() in difficulties) &&
            (clearTypes.isEmpty() || score.clearType in clearTypes) &&
            (djLevels.isEmpty() || score.djLevel in djLevels)
}

enum class IIDXNewEntryKind(val key: String) {
    HIGH_SCORES("newHighScores"),
    AAA("newAAA"),
    AA("newAA"),
    A("newA"),
    FULL_COMBO_CLEAR("newFullComboClear"),
    CLEAR("newClears"),
    EASY_CLEAR("newEasyClears"),
    ASSIST_CLEAR("newAssistClears"),
    HARD_CLEAR("newHardClear"),
    EX_HARD_CLEAR("newExHardClear"),
    FAILED("newFailed");

    companion object {
        fun fromKey(key: String): IIDXNewEntryKind? = entries.firstOrNull { it.key == key }

        fun forClearType(clearType: String): IIDXNewEntryKind? = when (clearType) {
            IIDXClearType.FULL_COMBO_CLEAR.value -> FULL_COMBO_CLEAR
            IIDXClearType.CLEAR.value -> CLEAR
            IIDXClearType.EASY_CLEAR.value -> EASY_CLEAR
            IIDXClearType.ASSIST_CLEAR.value -> ASSIST_CLEAR
            IIDXClearType.HARD_CLEAR.value -> HARD_CLEAR
            IIDXClearType.EX_HARD_CLEAR.value -> EX_HARD_CLEAR
            IIDXClearType.FAILED.value -> FAILED
            else -> null
        }

        fun forDJLevel(djLevel: String): IIDXNewEntryKind? = when (djLevel) {
            IIDXDJLevel.AAA.value -> AAA
            IIDXDJLevel.AA.value -> AA
            IIDXDJLevel.A.value -> A
            else -> null
        }
    }
}

data class IIDXNewEntry(
    val record: IIDXSongRecord,
    val level: IIDXLevel,
    val score: IIDXLevelScore,
    val previousScore: Int
)

data class IIDXTrendPoint(val date: Long, val counts: Map<Int, Map<String, Int>>)

data class IIDXAnalyticsData(
    val clearTypePerDifficulty: Map<Int, Map<String, Int>> = emptyMap(),
    val djLevelPerDifficulty: Map<Int, Map<String, Int>> = emptyMap(),
    val clearTypeTrends: List<IIDXTrendPoint> = emptyList(),
    val djLevelTrends: List<IIDXTrendPoint> = emptyList(),
    val newEntries: Map<IIDXNewEntryKind, List<IIDXNewEntry>> = emptyMap(),
    val towerEntries: List<IIDXTowerEntry> = emptyList()
) {
    fun newEntries(kind: IIDXNewEntryKind): List<IIDXNewEntry> = newEntries[kind].orEmpty()

    val towerTotalKeyCount: Int
        get() = towerEntries.sumOf { it.keyCount } / 100

    val towerTotalScratchCount: Int
        get() = towerEntries.sumOf { it.scratchCount } / 100

    val totalDJLevelCounts: List<Pair<String, Int>>
        get() = IIDXDJLevel.sorted.reversed().map { djLevel ->
            djLevel.value to djLevelPerDifficulty.values.sumOf { it[djLevel.value] ?: 0 }
        }

    fun towerChartEntries(nowEpoch: Long): List<IIDXTowerEntry> {
        val cutoff = nowEpoch - 30L * 24 * 60 * 60
        val recent = towerEntries.takeWhile { it.playDate >= cutoff }
        return (if (recent.size >= 5) recent else towerEntries.take(5)).reversed()
    }
}

object IIDXAnalytics {

    val difficulties: List<Int> = (1..12).toList()

    private val clearTypeKeys = IIDXClearType.sortedWithoutNoPlay.map { it.value }
    private val djLevelKeys = IIDXDJLevel.sorted.reversed().map { it.value }

    suspend fun compute(
        dao: IIDXDao,
        playType: IIDXPlayType,
        filters: IIDXFilterOptions
    ): IIDXAnalyticsData {
        val groups = dao.importGroups(IIDXVersionInfo.NUMBER).sortedBy { it.importDate }
        val towerEntries = dao.towerEntries()
        if (groups.isEmpty()) return IIDXAnalyticsData(towerEntries = towerEntries)

        val aggregates = levelAggregates(dao, groups.map { it.id }, playType)
            .filter { (level, aggregate) -> aggregateMatches(level, aggregate, filters) }
            .map { it.second }
        val clearTypeByGroup = HashMap<String, MutableMap<Int, MutableMap<String, Int>>>()
        val djLevelByGroup = HashMap<String, MutableMap<Int, MutableMap<String, Int>>>()
        aggregates.forEach { aggregate ->
            if (aggregate.hasScore && aggregate.clearType != IIDXClearType.NO_PLAY.value) {
                clearTypeByGroup.getOrPut(aggregate.groupID) { mutableMapOf() }
                    .getOrPut(aggregate.difficulty) { mutableMapOf() }
                    .merge(aggregate.clearType, aggregate.count, Int::plus)
            }
            if (aggregate.djLevel != IIDXDJLevel.NONE.value) {
                djLevelByGroup.getOrPut(aggregate.groupID) { mutableMapOf() }
                    .getOrPut(aggregate.difficulty) { mutableMapOf() }
                    .merge(aggregate.djLevel, aggregate.count, Int::plus)
            }
        }

        val latestGroup = groups.last()
        val clearTypeTrends = groups.mapNotNull { group ->
            val counts = ordered(clearTypeByGroup[group.id].orEmpty(), clearTypeKeys)
            if (counts.values.sumOf { it.values.sum() } > 0) IIDXTrendPoint(group.importDate, counts) else null
        }
        val djLevelTrends = groups.mapNotNull { group ->
            val counts = ordered(djLevelByGroup[group.id].orEmpty(), djLevelKeys)
            if (counts.values.sumOf { it.values.sum() } > 0) IIDXTrendPoint(group.importDate, counts) else null
        }
        val latestClearTypes = clearTypeByGroup[latestGroup.id]
        return IIDXAnalyticsData(
            clearTypePerDifficulty = if (latestClearTypes.isNullOrEmpty()) {
                emptyMap()
            } else {
                ordered(latestClearTypes, clearTypeKeys)
            },
            djLevelPerDifficulty = if (latestClearTypes.isNullOrEmpty()) {
                emptyMap()
            } else {
                ordered(djLevelByGroup[latestGroup.id].orEmpty(), djLevelKeys)
            },
            clearTypeTrends = clearTypeTrends,
            djLevelTrends = djLevelTrends,
            newEntries = newEntries(dao, groups, playType, filters),
            towerEntries = towerEntries
        )
    }

    private fun aggregateMatches(
        level: IIDXLevel,
        aggregate: IIDXLevelAggregate,
        filters: IIDXFilterOptions
    ): Boolean =
        (filters.versions.isEmpty() || aggregate.version in filters.versions) &&
            (filters.levels.isEmpty() || level.code in filters.levels) &&
            (filters.difficulties.isEmpty() || aggregate.difficulty.toString() in filters.difficulties) &&
            (filters.clearTypes.isEmpty() || aggregate.clearType in filters.clearTypes) &&
            (filters.djLevels.isEmpty() || aggregate.djLevel in filters.djLevels) &&
            (!filters.onlyPlayDataWithScores || aggregate.hasScore)

    private suspend fun levelAggregates(
        dao: IIDXDao,
        groupIDs: List<String>,
        playType: IIDXPlayType
    ): List<Pair<IIDXLevel, IIDXLevelAggregate>> {
        val placeholders = groupIDs.joinToString(",") { "?" }
        return IIDXLevel.entries.flatMap { level ->
            val prefix = level.name.lowercase() + "_"
            val query = SimpleSQLiteQuery(
                "SELECT importGroupID AS groupID, version, ${prefix}difficulty AS difficulty, " +
                    "${prefix}clearType AS clearType, ${prefix}djLevel AS djLevel, " +
                    "(${prefix}score > 0) AS hasScore, COUNT(*) AS count FROM IIDXSongRecord " +
                    "WHERE playType = ? AND ${prefix}difficulty > 0 AND importGroupID IN ($placeholders) " +
                    "GROUP BY importGroupID, version, ${prefix}difficulty, ${prefix}clearType, " +
                    "${prefix}djLevel, hasScore",
                (listOf<Any>(playType.value) + groupIDs).toTypedArray()
            )
            dao.levelAggregates(query).map { level to it }
        }
    }

    private fun ordered(
        counts: Map<Int, Map<String, Int>>,
        keys: List<String>
    ): Map<Int, Map<String, Int>> =
        difficulties.associateWith { difficulty ->
            val levelCounts = counts[difficulty].orEmpty()
            keys.associateWith { levelCounts[it] ?: 0 }
        }

    private suspend fun newEntries(
        dao: IIDXDao,
        groups: List<IIDXImportGroup>,
        playType: IIDXPlayType,
        filters: IIDXFilterOptions
    ): Map<IIDXNewEntryKind, List<IIDXNewEntry>> {
        if (groups.size < 2) return emptyMap()
        val latestRecords = dao.songRecords(groups[groups.size - 1].id, playType.value)
            .sortedBy { it.lastPlayDate }
        val previousRecords = dao.songRecords(groups[groups.size - 2].id, playType.value)
        return computeNewEntries(latestRecords, previousRecords, filters)
    }

    fun matchKey(record: IIDXSongRecord): String =
        record.title.compact + "\u0001" + record.artist.compact

    fun computeNewEntries(
        latestRecords: List<IIDXSongRecord>,
        previousRecords: List<IIDXSongRecord>,
        filters: IIDXFilterOptions
    ): Map<IIDXNewEntryKind, List<IIDXNewEntry>> {
        val previousByKey = previousRecords.associateBy { matchKey(it) }
        val result = IIDXNewEntryKind.entries.associateWith { mutableListOf<IIDXNewEntry>() }
        for (latest in latestRecords) {
            if (filters.versions.isNotEmpty() && latest.version !in filters.versions) continue
            val previous = previousByKey[matchKey(latest)]
            for (level in IIDXLevel.entries) {
                val score = latest.slot(level)
                if (score.difficulty <= 0 || score.score <= 0) continue
                if (!filters.matches(level, score)) continue
                val previousScore = previous?.slot(level)
                val previousClearType = previousScore?.clearType ?: IIDXClearType.NO_PLAY.value
                val previousDJLevel = previousScore?.djLevel ?: IIDXDJLevel.NONE.value
                val previousScoreValue = previousScore?.score ?: 0
                val entry = IIDXNewEntry(latest, level, score, previousScoreValue)
                IIDXNewEntryKind.forClearType(score.clearType)?.let { kind ->
                    if (previousClearType != score.clearType) result.getValue(kind).add(entry)
                }
                IIDXNewEntryKind.forDJLevel(score.djLevel)?.let { kind ->
                    if (previousDJLevel != score.djLevel) result.getValue(kind).add(entry)
                }
                if (score.score > previousScoreValue) {
                    result.getValue(IIDXNewEntryKind.HIGH_SCORES).add(entry)
                }
            }
        }
        return result
    }
}
