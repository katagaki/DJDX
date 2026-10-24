package com.tsubuzaki.djdxgo.data.polarischord

import com.tsubuzaki.djdxgo.data.dayBucket
import java.util.Locale
import java.util.UUID
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive

@Serializable
data class PolarisChordScrapedRow(
    val musicID: String = "",
    val title: String = "",
    val category: String = "",
    val difficulty: JsonPrimitive? = null,
    val level: String = "",
    val rate: JsonPrimitive? = null,
    val score: JsonPrimitive? = null,
    val clearStatus: JsonPrimitive? = null
)

class PolarisChordRepository(private val dao: PolarisChordDao) {

    private val json = Json { ignoreUnknownKeys = true }

    suspend fun importJSON(payload: String, importDate: Long): Int {
        val rows = runCatching {
            json.decodeFromString<List<PolarisChordScrapedRow>>(payload)
        }.getOrElse { return 0 }
        if (rows.isEmpty()) return 0
        val groupID = prepareImportGroup(importDate)
        val records = rows.mapNotNull { row ->
            if (row.title.isEmpty()) return@mapNotNull null
            val rate = row.rate.intOrZero()
            PolarisChordSongRecord(
                importGroupID = groupID,
                title = row.title,
                musicID = row.musicID,
                category = row.category,
                difficulty = PolarisChordDifficulty.fromTypeCode(row.difficulty.intOrZero())?.value ?: "",
                level = row.level,
                achievementRate = if (rate > 0) {
                    String.format(Locale.US, "%.2f", rate / 100.0)
                } else {
                    ""
                },
                score = row.score.intOrZero(),
                clearType = PolarisChordClearType.fromStatusCode(row.clearStatus.intOrZero()).value,
                grade = PolarisChordGrade.forAchievementRate(rate).value
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
        val group = PolarisChordImportGroup(
            id = UUID.randomUUID().toString(),
            importDate = importDate,
            version = PolarisChordVersionInfo.NUMBER
        )
        dao.insertImportGroup(group)
        return group.id
    }

    suspend fun importGroupFor(date: Long): PolarisChordImportGroup? {
        val bucket = dayBucket(date)
        return dao.importGroup(bucket.startOfDay, bucket.startOfNextDay)
            ?: dao.closestImportGroupBefore(bucket.startOfNextDay)
    }

    suspend fun songRecords(date: Long): List<PolarisChordSongRecord> {
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
