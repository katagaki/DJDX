package com.tsubuzaki.djdxgo.data.sdvx

import com.tsubuzaki.djdxgo.data.Csv
import com.tsubuzaki.djdxgo.data.dayBucket
import java.util.UUID

class SDVXRepository(private val dao: SDVXDao) {

    suspend fun importCSV(csv: String, importDate: Long, version: SDVXVersion): Int {
        val content = csv.removePrefix("﻿")
        if (!content.contains("楽曲名")) return 0
        val rows = Csv.keyedRows(content)
        if (rows.isEmpty()) return 0
        val groupID = prepareImportGroup(importDate, version)
        val records = rows.mapNotNull { row ->
            val title = row["楽曲名"] ?: return@mapNotNull null
            if (title.isEmpty()) return@mapNotNull null
            SDVXSongRecord(
                importGroupID = groupID,
                title = title,
                difficulty = row["難易度"] ?: "",
                level = row["楽曲レベル"] ?: "",
                clearType = row["クリアランク"] ?: "NO PLAY",
                grade = row["スコアグレード"] ?: "---",
                highScore = row["ハイスコア"]?.toIntOrNull() ?: 0,
                exScore = row["EXスコア"]?.toIntOrNull() ?: 0,
                playCount = row["プレー回数"]?.toIntOrNull() ?: 0,
                clearCount = row["クリア回数"]?.toIntOrNull() ?: 0,
                ultimateChainCount = row["ULTIMATE CHAIN"]?.toIntOrNull() ?: 0,
                perfectCount = row["PERFECT"]?.toIntOrNull() ?: 0
            )
        }
        dao.insertSongRecords(records)
        return records.size
    }

    private suspend fun prepareImportGroup(importDate: Long, version: SDVXVersion): String {
        val bucket = dayBucket(importDate)
        val existing = dao.importGroup(bucket.startOfDay, bucket.startOfNextDay)
        if (existing != null) {
            dao.deleteSongRecords(existing.id)
            return existing.id
        }
        val group = SDVXImportGroup(
            id = UUID.randomUUID().toString(),
            importDate = importDate,
            version = version.number
        )
        dao.insertImportGroup(group)
        return group.id
    }

    suspend fun importGroupFor(date: Long): SDVXImportGroup? {
        val bucket = dayBucket(date)
        return dao.importGroup(bucket.startOfDay, bucket.startOfNextDay)
            ?: dao.closestImportGroupBefore(bucket.startOfNextDay)
    }

    suspend fun songRecords(date: Long): List<SDVXSongRecord> {
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
