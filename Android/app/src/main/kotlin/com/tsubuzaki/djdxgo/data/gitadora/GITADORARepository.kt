package com.tsubuzaki.djdxgo.data.gitadora

import com.tsubuzaki.djdxgo.data.dayBucket
import java.util.Locale
import java.util.UUID
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive

@Serializable
data class GITADORAScrapedRow(
    val title: String = "",
    val instrument: String = "",
    val difficulty: String = "",
    val level: JsonPrimitive? = null,
    val rate: JsonPrimitive? = null,
    val score: JsonPrimitive? = null,
    val rank: String = "",
    val clear: String = ""
)

@Serializable
data class GITADORAScrapedProfile(
    val name: String = "",
    val skill: Map<String, Double> = emptyMap()
)

@Serializable
data class GITADORAScrapedPayload(
    val profile: GITADORAScrapedProfile? = null,
    val rows: List<GITADORAScrapedRow> = emptyList()
)

class GITADORARepository(private val dao: GITADORADao) {

    private val json = Json { ignoreUnknownKeys = true }

    fun parsePayload(payload: String): GITADORAScrapedPayload? =
        runCatching { json.decodeFromString<GITADORAScrapedPayload>(payload) }.getOrNull()

    suspend fun importJSON(payload: String, importDate: Long): Int {
        val parsed = parsePayload(payload) ?: return 0
        if (parsed.rows.isEmpty()) return 0
        val groupID = prepareImportGroup(importDate)
        val records = parsed.rows.mapNotNull { row ->
            val title = row.title.trim()
            val instrument = GITADORAInstrument.fromValue(row.instrument) ?: return@mapNotNull null
            val difficulty = GITADORADifficulty.fromValue(row.difficulty) ?: return@mapNotNull null
            if (title.isEmpty()) return@mapNotNull null
            val rate = row.rate.decimalOrNull()
            val clearType = GITADORAClearType.fromValue(row.clear) ?: GITADORAClearType.NO_PLAY
            val rank = GITADORARank.fromValue(row.rank.uppercase())?.takeIf { it != GITADORARank.NONE }
                ?: rate?.let { GITADORARank.forAchievementRate(it) }
                ?: GITADORARank.NONE
            GITADORASongRecord(
                importGroupID = groupID,
                title = title,
                instrument = instrument.value,
                difficulty = difficulty.value,
                level = row.level.decimalOrNull()?.let { String.format(Locale.US, "%.2f", it) }.orEmpty(),
                achievementRate = rate?.let { String.format(Locale.US, "%.2f", it) }.orEmpty(),
                score = row.score?.content?.filter { it.isDigit() }?.toIntOrNull() ?: 0,
                clearType = clearType.value,
                rank = rank.value
            )
        }
        dao.insertSongRecords(records)
        return records.size
    }

    private fun JsonPrimitive?.decimalOrNull(): Double? =
        this?.content?.filter { it.isDigit() || it == '.' }?.toDoubleOrNull()

    private suspend fun prepareImportGroup(importDate: Long): String {
        val bucket = dayBucket(importDate)
        val existing = dao.importGroup(bucket.startOfDay, bucket.startOfNextDay)
        if (existing != null) {
            dao.deleteSongRecords(existing.id)
            return existing.id
        }
        val group = GITADORAImportGroup(
            id = UUID.randomUUID().toString(),
            importDate = importDate,
            version = GITADORAVersionInfo.NUMBER
        )
        dao.insertImportGroup(group)
        return group.id
    }

    suspend fun importGroupFor(date: Long): GITADORAImportGroup? {
        val bucket = dayBucket(date)
        return dao.importGroup(bucket.startOfDay, bucket.startOfNextDay)
            ?: dao.closestImportGroupBefore(bucket.startOfNextDay)
    }

    suspend fun songRecords(date: Long): List<GITADORASongRecord> {
        val group = importGroupFor(date) ?: return emptyList()
        return dao.songRecords(group.id)
    }

    suspend fun deleteImportGroup(groupID: String) {
        dao.deleteSongRecords(groupID)
        dao.deleteImportGroup(groupID)
    }

    suspend fun deleteAllData() {
        dao.deleteAllScoreData()
        dao.deleteAllImportGroups()
    }
}
