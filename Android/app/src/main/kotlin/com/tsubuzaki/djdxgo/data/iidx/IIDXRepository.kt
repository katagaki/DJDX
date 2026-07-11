package com.tsubuzaki.djdxgo.data.iidx

import com.tsubuzaki.djdxgo.data.Csv
import com.tsubuzaki.djdxgo.data.dayBucket
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.UUID

class IIDXRepository(private val dao: IIDXDao) {

    private val lastPlayDateFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")
    private val towerDateFormatter = DateTimeFormatter.ofPattern("yyyy/MM/dd")

    suspend fun importCSV(csv: String, importDate: Long, playType: IIDXPlayType): Int {
        val rows = Csv.keyedRows(csv)
        if (rows.isEmpty()) return 0
        val groupID = prepareImportGroup(importDate, playType)
        val records = rows.mapNotNull { row -> songRecord(row, groupID, playType) }
        dao.insertSongRecords(records)
        return records.size
    }

    suspend fun importTowerCSV(csv: String): Int {
        val rows = Csv.keyedRows(csv)
        if (rows.isEmpty()) return 0
        val entries = rows.mapNotNull { row ->
            val playDate = row["プレー日"]?.let {
                runCatching {
                    LocalDate.parse(it, towerDateFormatter)
                        .atStartOfDay(ZoneId.systemDefault())
                        .toEpochSecond()
                }.getOrNull()
            } ?: return@mapNotNull null
            IIDXTowerEntry(
                playDate = playDate,
                keyCount = row["鍵盤"]?.toIntOrNull() ?: 0,
                scratchCount = row["スクラッチ"]?.toIntOrNull() ?: 0
            )
        }
        dao.deleteAllTowerEntries()
        dao.insertTowerEntries(entries)
        return entries.size
    }

    private suspend fun prepareImportGroup(importDate: Long, playType: IIDXPlayType): String {
        val bucket = dayBucket(importDate)
        val existing = dao.importGroup(bucket.startOfDay, bucket.startOfNextDay)
        if (existing != null) {
            dao.deleteSongRecords(existing.id, playType.value)
            return existing.id
        }
        val group = IIDXImportGroup(
            id = UUID.randomUUID().toString(),
            importDate = importDate,
            iidxVersion = IIDXVersionInfo.NUMBER
        )
        dao.insertImportGroup(group)
        return group.id
    }

    private fun songRecord(
        row: Map<String, String>,
        groupID: String,
        playType: IIDXPlayType
    ): IIDXSongRecord? {
        val title = row["タイトル"] ?: return null
        val lastPlayDate = row["最終プレー日時"]?.let {
            runCatching {
                LocalDateTime.parse(it, lastPlayDateFormatter)
                    .atZone(ZoneId.systemDefault())
                    .toEpochSecond()
            }.getOrNull()
        } ?: 0

        fun slot(level: IIDXLevel): IIDXLevelScore {
            val prefix = level.csvPrefix
            return IIDXLevelScore(
                level = if ((row["$prefix 難易度"]?.toIntOrNull() ?: 0) != 0) level.code else "",
                difficulty = row["$prefix 難易度"]?.toIntOrNull() ?: 0,
                score = row["$prefix スコア"]?.toIntOrNull() ?: 0,
                perfectGreatCount = row["$prefix PGreat"]?.toIntOrNull() ?: 0,
                greatCount = row["$prefix Great"]?.toIntOrNull() ?: 0,
                missCount = row["$prefix ミスカウント"]?.toIntOrNull() ?: 0,
                clearType = row["$prefix クリアタイプ"] ?: "NO PLAY",
                djLevel = row["$prefix DJ LEVEL"] ?: "---"
            )
        }

        return IIDXSongRecord(
            importGroupID = groupID,
            version = row["バージョン"] ?: "",
            title = title,
            genre = row["ジャンル"] ?: "",
            artist = row["アーティスト"] ?: "",
            playCount = row["プレー回数"]?.toIntOrNull() ?: 0,
            playType = playType.value,
            lastPlayDate = lastPlayDate,
            beginner = slot(IIDXLevel.BEGINNER),
            normal = slot(IIDXLevel.NORMAL),
            hyper = slot(IIDXLevel.HYPER),
            another = slot(IIDXLevel.ANOTHER),
            leggendaria = slot(IIDXLevel.LEGGENDARIA)
        )
    }

    suspend fun importGroupFor(date: Long): IIDXImportGroup? {
        val bucket = dayBucket(date)
        return dao.importGroup(bucket.startOfDay, bucket.startOfNextDay)
            ?: dao.closestImportGroupBefore(bucket.startOfNextDay)
    }

    suspend fun songRecords(date: Long, playType: IIDXPlayType): List<IIDXSongRecord> {
        val group = importGroupFor(date) ?: return emptyList()
        return dao.songRecords(group.id, playType.value)
    }

    suspend fun deleteImportGroup(groupID: String) {
        dao.deleteAllSongRecords(groupID)
        dao.deleteImportGroup(groupID)
    }

    suspend fun deleteAllData() {
        dao.deleteAllScoreData()
        dao.deleteAllImportGroups()
        dao.deleteAllTowerEntries()
    }
}
