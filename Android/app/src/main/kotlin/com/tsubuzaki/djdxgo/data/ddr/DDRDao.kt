package com.tsubuzaki.djdxgo.data.ddr

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import com.tsubuzaki.djdxgo.data.ScoreHistoryPoint
import kotlinx.coroutines.flow.Flow

@Dao
interface DDRDao {
    @Insert
    suspend fun insertImportGroup(group: DDRImportGroup)

    @Insert
    suspend fun insertSongRecords(records: List<DDRSongRecord>)

    @Query("SELECT * FROM DDRImportGroup ORDER BY importDate DESC")
    fun importGroupsFlow(): Flow<List<DDRImportGroup>>

    @Query("SELECT * FROM DDRImportGroup ORDER BY importDate DESC")
    suspend fun importGroups(): List<DDRImportGroup>

    @Query(
        "SELECT * FROM DDRImportGroup WHERE importDate >= :startOfDay AND importDate < :startOfNextDay LIMIT 1"
    )
    suspend fun importGroup(startOfDay: Long, startOfNextDay: Long): DDRImportGroup?

    @Query(
        "SELECT * FROM DDRImportGroup WHERE importDate < :date ORDER BY importDate DESC LIMIT 1"
    )
    suspend fun closestImportGroupBefore(date: Long): DDRImportGroup?

    @Query("DELETE FROM DDRSongRecord WHERE importGroupID = :groupID")
    suspend fun deleteSongRecords(groupID: String)

    @Query("DELETE FROM DDRImportGroup WHERE id = :groupID")
    suspend fun deleteImportGroup(groupID: String)

    @Query("SELECT * FROM DDRSongRecord WHERE importGroupID = :groupID AND style = :style ORDER BY title")
    suspend fun songRecords(groupID: String, style: String): List<DDRSongRecord>

    @Query("SELECT * FROM DDRSongRecord WHERE importGroupID = :groupID AND songIndex = :songIndex ORDER BY id")
    suspend fun songRecordsForIndex(groupID: String, songIndex: String): List<DDRSongRecord>

    @Query(
        "SELECT g.importDate AS date, r.score AS score FROM DDRSongRecord r " +
            "JOIN DDRImportGroup g ON r.importGroupID = g.id " +
            "WHERE r.songIndex = :songIndex AND r.style = :style AND r.difficulty = :difficulty " +
            "AND r.score > 0 ORDER BY g.importDate"
    )
    suspend fun scoreHistory(songIndex: String, style: String, difficulty: String): List<ScoreHistoryPoint>

    @Query(
        "SELECT g.importDate AS date, r.title, r.flareSkill FROM DDRSongRecord r " +
            "JOIN DDRImportGroup g ON r.importGroupID = g.id WHERE r.style = :style AND r.flareSkill > 0"
    )
    suspend fun flareSkillRows(style: String): List<DDRFlareSkillRow>

    @Query("DELETE FROM DDRSongRecord")
    suspend fun deleteAllScoreData()

    @Query("DELETE FROM DDRImportGroup")
    suspend fun deleteAllImportGroups()
}
