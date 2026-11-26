package com.tsubuzaki.djdxgo.data.analytics

import android.content.Context
import com.tsubuzaki.djdxgo.data.DJDXDatabase
import com.tsubuzaki.djdxgo.data.Game
import com.tsubuzaki.djdxgo.data.SettingsKeys
import com.tsubuzaki.djdxgo.data.ddr.DDRClearLamp
import com.tsubuzaki.djdxgo.data.ddr.DDRPlayStyle
import com.tsubuzaki.djdxgo.data.ddr.DDRRank
import com.tsubuzaki.djdxgo.data.ddr.DDRRepository
import com.tsubuzaki.djdxgo.data.ddr.DDRSongRecord
import com.tsubuzaki.djdxgo.data.iidx.IIDXClearType
import com.tsubuzaki.djdxgo.data.iidx.IIDXDJLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import com.tsubuzaki.djdxgo.data.iidx.IIDXSongRecord
import com.tsubuzaki.djdxgo.data.iidx.IIDXVersionInfo
import com.tsubuzaki.djdxgo.data.sdvx.SDVXClearType
import com.tsubuzaki.djdxgo.data.sdvx.SDVXGrade
import com.tsubuzaki.djdxgo.data.sdvx.SDVXSongRecord
import com.tsubuzaki.djdxgo.data.sdvx.SDVXVolforce
import com.tsubuzaki.djdxgo.data.setSetting
import com.tsubuzaki.djdxgo.data.settingFlow
import java.time.Instant
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import java.util.UUID
import kotlin.math.roundToInt
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
enum class AnalyticsGoalKind {
    RATING,
    CLEAR_COUNT,
    GRADE_COUNT;

    companion object {
        fun available(game: Game): List<AnalyticsGoalKind> = when (game) {
            Game.SOUND_VOLTEX, Game.DANCE_DANCE_REVOLUTION -> listOf(RATING, CLEAR_COUNT, GRADE_COUNT)
            Game.IIDX_ARCADE -> listOf(CLEAR_COUNT, GRADE_COUNT)
            Game.POLARIS_CHORD -> emptyList()
        }
    }
}

@Serializable
data class AnalyticsGoal(
    val id: String = UUID.randomUUID().toString(),
    val game: Int,
    val kind: AnalyticsGoalKind,
    val playStyle: String = "",
    val level: Int = 0,
    val threshold: String = "",
    val target: Double,
    val startDate: Long = System.currentTimeMillis() / 1000L,
    val startValue: Double? = null,
    val deadline: Long
) {
    val gameEnum: Game get() = Game.fromId(game)

    val isRating: Boolean get() = kind == AnalyticsGoalKind.RATING

    val title: String
        get() = when (kind) {
            AnalyticsGoalKind.RATING ->
                if (gameEnum == Game.DANCE_DANCE_REVOLUTION) "FLARE SKILL" else "VOLFORCE"
            else -> (if (level > 0) "LEVEL $level " else "") + thresholdDisplay(threshold, kind, gameEnum)
        }

    val subtitle: String?
        get() = when (gameEnum) {
            Game.IIDX_ARCADE -> IIDXPlayType.fromValue(playStyle).displayName
            Game.DANCE_DANCE_REVOLUTION -> DDRPlayStyle.fromValue(playStyle).displayName
            else -> null
        }

    fun formatted(value: Double): String =
        if (isRating && gameEnum == Game.SOUND_VOLTEX) {
            String.format(java.util.Locale.US, "%.2f", value)
        } else {
            value.roundToInt().toString()
        }

    companion object {
        fun thresholdOptions(kind: AnalyticsGoalKind, game: Game): List<String> = when (kind) {
            AnalyticsGoalKind.RATING -> emptyList()
            AnalyticsGoalKind.CLEAR_COUNT -> when (game) {
                Game.IIDX_ARCADE -> IIDXClearType.ascending.drop(2).reversed().map { it.value }
                Game.SOUND_VOLTEX -> SDVXClearType.sorted
                    .filter { it != SDVXClearType.NO_PLAY && it != SDVXClearType.PLAYED }
                    .map { it.value }
                Game.DANCE_DANCE_REVOLUTION -> DDRClearLamp.order.filter { it != "fail" }
                Game.POLARIS_CHORD -> emptyList()
            }
            AnalyticsGoalKind.GRADE_COUNT -> when (game) {
                Game.IIDX_ARCADE -> IIDXDJLevel.sorted.reversed().map { it.value }
                Game.SOUND_VOLTEX -> SDVXGrade.sorted.filter { it != SDVXGrade.NONE }.map { it.value }
                Game.DANCE_DANCE_REVOLUTION -> DDRRank.order
                Game.POLARIS_CHORD -> emptyList()
            }
        }

        fun defaultThreshold(kind: AnalyticsGoalKind, game: Game): String = when {
            game == Game.IIDX_ARCADE && kind == AnalyticsGoalKind.CLEAR_COUNT -> IIDXClearType.HARD_CLEAR.value
            game == Game.IIDX_ARCADE && kind == AnalyticsGoalKind.GRADE_COUNT -> IIDXDJLevel.AA.value
            else -> thresholdOptions(kind, game).firstOrNull().orEmpty()
        }

        fun levelOptions(game: Game): List<Int> = when (game) {
            Game.IIDX_ARCADE -> (1..12).toList()
            Game.SOUND_VOLTEX -> (1..20).toList()
            Game.DANCE_DANCE_REVOLUTION -> (1..19).toList()
            Game.POLARIS_CHORD -> emptyList()
        }

        fun thresholdDisplay(threshold: String, kind: AnalyticsGoalKind, game: Game): String =
            if (game != Game.DANCE_DANCE_REVOLUTION) {
                threshold
            } else {
                when (kind) {
                    AnalyticsGoalKind.CLEAR_COUNT -> DDRClearLamp.display(threshold)
                    AnalyticsGoalKind.GRADE_COUNT -> DDRRank.display(threshold)
                    AnalyticsGoalKind.RATING -> threshold
                }
            }
    }
}

enum class AnalyticsGoalStatus {
    ACHIEVED,
    AHEAD,
    ON_PACE,
    BEHIND,
    MISSED,
    NOT_STARTED
}

data class AnalyticsGoalPoint(val date: Long, val value: Double)

data class AnalyticsGoalProgress(
    val goal: AnalyticsGoal,
    val history: List<AnalyticsGoalPoint>,
    val now: Long = System.currentTimeMillis() / 1000L
) {
    val historicalBaseline: Double =
        history.lastOrNull { it.date <= goal.startDate }?.value ?: history.firstOrNull()?.value ?: 0.0

    val baseline: Double = goal.startValue ?: historicalBaseline

    val current: Double = history.lastOrNull()?.value ?: baseline

    val timeFraction: Double
        get() {
            val total = goal.deadline - goal.startDate
            if (total <= 0) return 1.0
            return ((now - goal.startDate).toDouble() / total).coerceIn(0.0, 1.0)
        }

    val expected: Double get() = expectedAt(now)

    val latestUpdate: AnalyticsGoalPoint?
        get() {
            val latest = history.lastOrNull() ?: return null
            if (latest.date <= goal.startDate && latest.value == baseline) return null
            return AnalyticsGoalPoint(maxOf(latest.date, goal.startDate), latest.value)
        }

    fun expectedAt(date: Long): Double {
        val total = goal.deadline - goal.startDate
        if (total <= 0) return goal.target
        val fraction = ((date - goal.startDate).toDouble() / total).coerceIn(0.0, 1.0)
        return baseline + (goal.target - baseline) * fraction
    }

    val progressFraction: Double
        get() {
            val span = goal.target - baseline
            if (span <= 0) return if (current >= goal.target) 1.0 else 0.0
            return ((current - baseline) / span).coerceIn(0.0, 1.0)
        }

    val remaining: Double get() = (goal.target - current).coerceAtLeast(0.0)

    val daysLeft: Int
        get() {
            val zone = ZoneId.systemDefault()
            val today = Instant.ofEpochSecond(now).atZone(zone).toLocalDate()
            val due = Instant.ofEpochSecond(goal.deadline).atZone(zone).toLocalDate()
            return ChronoUnit.DAYS.between(today, due).toInt().coerceAtLeast(0)
        }

    val status: AnalyticsGoalStatus
        get() {
            if (current >= goal.target) return AnalyticsGoalStatus.ACHIEVED
            if (now >= goal.deadline) return AnalyticsGoalStatus.MISSED
            val update = latestUpdate ?: return AnalyticsGoalStatus.NOT_STARTED
            val gained = update.value - baseline
            if (gained <= 0) return AnalyticsGoalStatus.BEHIND
            val required = expectedAt(update.date) - baseline
            if (required <= 0) return AnalyticsGoalStatus.AHEAD
            val ratio = gained / required
            return when {
                ratio >= 1.15 -> AnalyticsGoalStatus.AHEAD
                ratio >= 0.9 -> AnalyticsGoalStatus.ON_PACE
                else -> AnalyticsGoalStatus.BEHIND
            }
        }
}

object AnalyticsGoalStore {
    private val json = Json { ignoreUnknownKeys = true }

    fun goalsFlow(context: Context): Flow<List<AnalyticsGoal>> =
        context.settingFlow(SettingsKeys.analyticsGoals, "").map(::decode)

    suspend fun upsert(context: Context, goal: AnalyticsGoal) {
        val goals = goalsFlow(context).first().toMutableList()
        val index = goals.indexOfFirst { it.id == goal.id }
        if (index >= 0) goals[index] = goal else goals.add(goal)
        save(context, goals)
    }

    suspend fun recordStartValues(context: Context, values: Map<String, Double>) {
        val goals = goalsFlow(context).first()
        var didChange = false
        val updated = goals.map { goal ->
            val value = values[goal.id]
            if (goal.startValue == null && value != null) {
                didChange = true
                goal.copy(startValue = value)
            } else {
                goal
            }
        }
        if (didChange) save(context, updated)
    }

    suspend fun delete(context: Context, id: String) {
        save(context, goalsFlow(context).first().filter { it.id != id })
    }

    private suspend fun save(context: Context, goals: List<AnalyticsGoal>) {
        context.setSetting(SettingsKeys.analyticsGoals, json.encodeToString(goals))
    }

    private fun decode(value: String): List<AnalyticsGoal> =
        if (value.isEmpty()) emptyList() else runCatching { json.decodeFromString<List<AnalyticsGoal>>(value) }
            .getOrDefault(emptyList())
}

class AnalyticsGoalEvaluator(
    private val context: Context,
    private val database: DJDXDatabase,
    private val ddrRepository: DDRRepository
) {

    suspend fun progress(goals: List<AnalyticsGoal>): List<AnalyticsGoalProgress> = withContext(Dispatchers.IO) {
        val histories = goals.groupBy { it.gameEnum }.flatMap { (game, gameGoals) ->
            when (game) {
                Game.IIDX_ARCADE -> iidxHistories(gameGoals)
                Game.SOUND_VOLTEX -> sdvxHistories(gameGoals)
                Game.DANCE_DANCE_REVOLUTION -> ddrHistories(gameGoals)
                Game.POLARIS_CHORD -> emptyList()
            }
        }.toMap()
        val progresses = goals.map { AnalyticsGoalProgress(it, histories[it.id].orEmpty()) }
        val startValues = progresses
            .filter { it.goal.startValue == null && it.history.isNotEmpty() }
            .associate { it.goal.id to it.historicalBaseline }
        if (startValues.isNotEmpty()) AnalyticsGoalStore.recordStartValues(context, startValues)
        progresses
    }

    private suspend fun iidxHistories(goals: List<AnalyticsGoal>): List<Pair<String, List<AnalyticsGoalPoint>>> {
        val dao = database.iidxDao()
        val groups = dao.importGroups(IIDXVersionInfo.NUMBER).sortedBy { it.importDate }
        val result = goals.associate { it.id to mutableListOf<AnalyticsGoalPoint>() }
        goals.groupBy { it.playStyle }.forEach { (playStyle, styleGoals) ->
            groups.forEach { group ->
                val records = dao.songRecords(group.id, IIDXPlayType.fromValue(playStyle).value)
                if (records.isEmpty()) return@forEach
                styleGoals.forEach { goal ->
                    result.getValue(goal.id).add(AnalyticsGoalPoint(group.importDate, iidxCount(records, goal).toDouble()))
                }
            }
        }
        return result.map { it.key to it.value }
    }

    private fun iidxCount(records: List<IIDXSongRecord>, goal: AnalyticsGoal): Int {
        val isClear = goal.kind == AnalyticsGoalKind.CLEAR_COUNT
        val ranking = if (isClear) {
            IIDXClearType.ascending.map { it.value }
        } else {
            IIDXDJLevel.sorted.map { it.value }
        }
        val thresholdRank = ranking.indexOf(goal.threshold).takeIf { it >= 0 } ?: return 0
        return records.sumOf { record ->
            record.playedLevels().count { (_, score) ->
                if (goal.level != 0 && score.difficulty != goal.level) return@count false
                if (isClear && score.score <= 0) return@count false
                ranking.indexOf(if (isClear) score.clearType else score.djLevel) >= thresholdRank
            }
        }
    }

    private suspend fun sdvxHistories(goals: List<AnalyticsGoal>): List<Pair<String, List<AnalyticsGoalPoint>>> {
        val dao = database.sdvxDao()
        val result = goals.associate { it.id to mutableListOf<AnalyticsGoalPoint>() }
        dao.importGroups().sortedBy { it.importDate }.forEach { group ->
            val records = dao.songRecords(group.id)
            if (records.isEmpty()) return@forEach
            goals.forEach { goal ->
                result.getValue(goal.id).add(AnalyticsGoalPoint(group.importDate, sdvxValue(records, goal)))
            }
        }
        return result.map { it.key to it.value }
    }

    private fun sdvxValue(records: List<SDVXSongRecord>, goal: AnalyticsGoal): Double = when (goal.kind) {
        AnalyticsGoalKind.RATING -> volforce(records)
        AnalyticsGoalKind.CLEAR_COUNT -> countAtOrAbove(
            records, SDVXClearType.sorted.filter { it != SDVXClearType.NO_PLAY }.map { it.value }, goal,
            { it.clearType }, { it.level.toDoubleOrNull()?.toInt() ?: 0 }
        ).toDouble()
        AnalyticsGoalKind.GRADE_COUNT -> countAtOrAbove(
            records, SDVXGrade.sorted.map { it.value }, goal,
            { it.grade }, { it.level.toDoubleOrNull()?.toInt() ?: 0 }
        ).toDouble()
    }

    private suspend fun ddrHistories(goals: List<AnalyticsGoal>): List<Pair<String, List<AnalyticsGoalPoint>>> {
        val result = goals.associate { it.id to mutableListOf<AnalyticsGoalPoint>() }
        database.ddrDao().importGroups().sortedBy { it.importDate }.forEach { group ->
            goals.groupBy { it.playStyle }.forEach { (playStyle, styleGoals) ->
                val records = ddrRepository.songRecordsForGroup(group.id, DDRPlayStyle.fromValue(playStyle))
                if (records.isEmpty()) return@forEach
                styleGoals.forEach { goal ->
                    result.getValue(goal.id).add(AnalyticsGoalPoint(group.importDate, ddrValue(records, goal)))
                }
            }
        }
        return result.map { it.key to it.value }
    }

    private fun ddrValue(records: List<DDRSongRecord>, goal: AnalyticsGoal): Double = when (goal.kind) {
        AnalyticsGoalKind.RATING ->
            records.map { it.flareSkill }.sortedDescending().take(DDR_FLARE_SKILL_CHARTS).sum().toDouble()
        AnalyticsGoalKind.CLEAR_COUNT ->
            countAtOrAbove(records, DDRClearLamp.order, goal, { it.clearKind }, { it.level }).toDouble()
        AnalyticsGoalKind.GRADE_COUNT ->
            countAtOrAbove(records, DDRRank.order, goal, { it.rank }, { it.level }).toDouble()
    }

    private fun <T> countAtOrAbove(
        records: List<T>,
        ranking: List<String>,
        goal: AnalyticsGoal,
        value: (T) -> String,
        levelOf: (T) -> Int
    ): Int {
        val thresholdRank = ranking.indexOf(goal.threshold).takeIf { it >= 0 } ?: return 0
        return records.count { record ->
            if (goal.level != 0 && levelOf(record) != goal.level) return@count false
            val rank = ranking.indexOf(value(record))
            rank in 0..thresholdRank
        }
    }

    companion object {
        private const val DDR_FLARE_SKILL_CHARTS = 90

        fun volforce(records: List<SDVXSongRecord>): Double = SDVXVolforce.total(records)
    }
}
