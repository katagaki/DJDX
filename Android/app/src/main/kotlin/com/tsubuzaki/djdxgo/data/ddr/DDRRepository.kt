package com.tsubuzaki.djdxgo.data.ddr

import com.tsubuzaki.djdxgo.data.dayBucket
import com.tsubuzaki.djdxgo.data.ddrCompact
import com.tsubuzaki.djdxgo.data.external.DDRSongMeta
import com.tsubuzaki.djdxgo.data.external.ExternalDataDao
import java.util.UUID
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
data class DDRScrapedRow(
    val songIndex: String = "",
    val title: String = "",
    val jacket: String = "",
    val style: String = "",
    val difficulty: String = "",
    val score: String = "",
    val rank: String = "",
    val clearKind: String = "",
    val flareSkill: String = "",
    val flareRank: String = ""
)

class DDRRepository(
    private val dao: DDRDao,
    private val externalDao: ExternalDataDao
) {

    private val json = Json { ignoreUnknownKeys = true }

    suspend fun importJSON(payload: String, importDate: Long): Int {
        val rows = runCatching {
            json.decodeFromString<List<DDRScrapedRow>>(payload)
        }.getOrElse { return 0 }
        if (rows.isEmpty()) return 0
        val groupID = prepareImportGroup(importDate)
        val records = rows.mapNotNull { row ->
            if (row.songIndex.isEmpty() || row.title.isEmpty()) return@mapNotNull null
            DDRSongRecord(
                importGroupID = groupID,
                songIndex = row.songIndex,
                title = row.title,
                style = DDRPlayStyle.fromValue(row.style).value,
                difficulty = DDRDifficulty.fromValue(row.difficulty)?.value ?: "",
                score = row.score.filter { it.isDigit() }.toIntOrNull() ?: 0,
                rank = strippedStem(row.rank, "rank_s_"),
                clearKind = strippedStem(row.clearKind, "cl_"),
                flareSkill = row.flareSkill.filter { it.isDigit() }.toIntOrNull() ?: 0,
                flareRank = strippedStem(row.flareRank, "flare_"),
                jacketPath = row.jacket
            )
        }
        dao.insertSongRecords(records)
        return records.size
    }

    private fun strippedStem(value: String, prefix: String): String {
        val stem = value.removePrefix(prefix)
        return if (stem == "none" || stem == "nodisp") "" else stem
    }

    private suspend fun prepareImportGroup(importDate: Long): String {
        val bucket = dayBucket(importDate)
        val existing = dao.importGroup(bucket.startOfDay, bucket.startOfNextDay)
        if (existing != null) {
            dao.deleteSongRecords(existing.id)
            return existing.id
        }
        val group = DDRImportGroup(
            id = UUID.randomUUID().toString(),
            importDate = importDate,
            version = DDRVersionInfo.NUMBER
        )
        dao.insertImportGroup(group)
        return group.id
    }

    suspend fun importGroupFor(date: Long): DDRImportGroup? {
        val bucket = dayBucket(date)
        return dao.importGroup(bucket.startOfDay, bucket.startOfNextDay)
            ?: dao.closestImportGroupBefore(bucket.startOfNextDay)
    }

    suspend fun songRecords(date: Long, style: DDRPlayStyle): List<DDRSongRecord> {
        val group = importGroupFor(date) ?: return emptyList()
        return applyMetadata(dao.songRecords(group.id, style.value))
    }

    private suspend fun applyMetadata(records: List<DDRSongRecord>): List<DDRSongRecord> {
        if (records.isEmpty()) return records
        val metaByTitle = externalDao.allDDRSongMetas().associateBy { it.titleCompact }
        if (metaByTitle.isEmpty()) return records
        return records.map { record ->
            val meta = metaByTitle[record.title.ddrCompact] ?: return@map record
            val level = meta.level(
                DDRPlayStyle.fromValue(record.style),
                DDRDifficulty.fromValue(record.difficulty)
            )
            if (level > 0) record.copy(level = level) else record
        }
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

private fun DDRSongMeta.level(style: DDRPlayStyle, difficulty: DDRDifficulty?): Int =
    when (style) {
        DDRPlayStyle.SINGLE -> when (difficulty) {
            DDRDifficulty.BEGINNER -> spBeginner
            DDRDifficulty.BASIC -> spBasic
            DDRDifficulty.DIFFICULT -> spDifficult
            DDRDifficulty.EXPERT -> spExpert
            DDRDifficulty.CHALLENGE -> spChallenge
            null -> 0
        }
        DDRPlayStyle.DOUBLE -> when (difficulty) {
            DDRDifficulty.BASIC -> dpBasic
            DDRDifficulty.DIFFICULT -> dpDifficult
            DDRDifficulty.EXPERT -> dpExpert
            DDRDifficulty.CHALLENGE -> dpChallenge
            else -> 0
        }
    }
