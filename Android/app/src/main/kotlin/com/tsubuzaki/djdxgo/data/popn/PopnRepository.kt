package com.tsubuzaki.djdxgo.data.popn

import com.tsubuzaki.djdxgo.data.dayBucket
import java.util.UUID
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive

@Serializable
data class PopnScrapedRow(
    val title: String = "",
    val genre: String = "",
    val artist: String = "",
    val difficulty: String = "",
    val level: JsonPrimitive? = null,
    val score: JsonPrimitive? = null,
    val medal: String = "",
    val rank: String = ""
)

@Serializable
data class PopnScrapedPayload(
    val rows: List<PopnScrapedRow> = emptyList()
)

class PopnRepository(private val dao: PopnDao) {

    private val json = Json { ignoreUnknownKeys = true }

    suspend fun importJSON(payload: String, importDate: Long): Int {
        val rows = runCatching {
            json.decodeFromString<PopnScrapedPayload>(payload).rows
        }.getOrElse { return 0 }
        if (rows.isEmpty()) return 0
        val groupID = prepareImportGroup(importDate)
        val records = rows.mapNotNull { row ->
            val difficulty = PopnDifficulty.fromLabel(row.difficulty) ?: return@mapNotNull null
            if (row.title.isBlank()) return@mapNotNull null
            PopnSongRecord(
                importGroupID = groupID,
                title = row.title.trim(),
                genre = row.genre.trim(),
                artist = row.artist.trim(),
                difficulty = difficulty.value,
                level = row.level.intOrZero(),
                score = row.score.intOrZero(),
                medal = PopnMedal.fromCode(row.medal).code,
                rank = PopnRank.fromCode(row.rank).value
            )
        }
        dao.insertSongRecords(records)
        return records.size
    }

    private fun JsonPrimitive?.intOrZero(): Int {
        val content = this?.content ?: return 0
        return content.toIntOrNull()
            ?: content.toDoubleOrNull()?.toInt()
            ?: content.filter { it.isDigit() }.toIntOrNull()
            ?: 0
    }

    private suspend fun prepareImportGroup(importDate: Long): String {
        val bucket = dayBucket(importDate)
        val existing = dao.importGroup(bucket.startOfDay, bucket.startOfNextDay)
        if (existing != null) {
            dao.deleteSongRecords(existing.id)
            return existing.id
        }
        val group = PopnImportGroup(
            id = UUID.randomUUID().toString(),
            importDate = importDate,
            version = PopnVersionInfo.NUMBER
        )
        dao.insertImportGroup(group)
        return group.id
    }

    suspend fun importGroupFor(date: Long): PopnImportGroup? {
        val bucket = dayBucket(date)
        return dao.importGroup(bucket.startOfDay, bucket.startOfNextDay)
            ?: dao.closestImportGroupBefore(bucket.startOfNextDay)
    }

    suspend fun importGroups(): List<PopnImportGroup> = dao.importGroups()

    suspend fun songRecords(groupID: String): List<PopnSongRecord> = dao.songRecords(groupID)

    suspend fun songRecords(date: Long): List<PopnSongRecord> {
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
