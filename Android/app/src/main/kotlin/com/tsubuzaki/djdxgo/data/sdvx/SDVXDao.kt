package com.tsubuzaki.djdxgo.data.sdvx

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import com.tsubuzaki.djdxgo.data.ScoreHistoryPoint
import kotlinx.coroutines.flow.Flow

@Dao
interface SDVXDao {
    @Insert
    suspend fun insertImportGroup(group: SDVXImportGroup)

    @Insert
    suspend fun insertSongRecords(records: List<SDVXSongRecord>)

    @Query("SELECT * FROM SDVXImportGroup ORDER BY importDate DESC")
    fun importGroupsFlow(): Flow<List<SDVXImportGroup>>

    @Query("SELECT * FROM SDVXImportGroup ORDER BY importDate DESC")
    suspend fun importGroups(): List<SDVXImportGroup>

    @Query(
        "SELECT * FROM SDVXImportGroup WHERE importDate >= :startOfDay AND importDate < :startOfNextDay LIMIT 1"
    )
    suspend fun importGroup(startOfDay: Long, startOfNextDay: Long): SDVXImportGroup?

    @Query(
        "SELECT * FROM SDVXImportGroup WHERE importDate < :date ORDER BY importDate DESC LIMIT 1"
    )
    suspend fun closestImportGroupBefore(date: Long): SDVXImportGroup?

    @Query("DELETE FROM SDVXSongRecord WHERE importGroupID = :groupID")
    suspend fun deleteSongRecords(groupID: String)

    @Query("DELETE FROM SDVXImportGroup WHERE id = :groupID")
    suspend fun deleteImportGroup(groupID: String)

    @Query("SELECT * FROM SDVXSongRecord WHERE importGroupID = :groupID ORDER BY title")
    suspend fun songRecords(groupID: String): List<SDVXSongRecord>

    @Query("SELECT * FROM SDVXSongRecord WHERE importGroupID = :groupID AND title = :title ORDER BY id")
    suspend fun songRecordsForTitle(groupID: String, title: String): List<SDVXSongRecord>

    @Query(
        "SELECT g.importDate AS date, r.highScore AS score FROM SDVXSongRecord r " +
            "JOIN SDVXImportGroup g ON r.importGroupID = g.id " +
            "WHERE r.title = :title AND r.difficulty = :difficulty AND r.highScore > 0 ORDER BY g.importDate"
    )
    suspend fun scoreHistory(title: String, difficulty: String): List<ScoreHistoryPoint>

    @Query(
        "SELECT g.importDate AS date, r.level, r.highScore, r.clearType FROM SDVXSongRecord r " +
            "JOIN SDVXImportGroup g ON r.importGroupID = g.id WHERE r.highScore > 0"
    )
    suspend fun volforceRows(): List<SDVXVolforceRow>

    @Query("DELETE FROM SDVXSongRecord")
    suspend fun deleteAllScoreData()

    @Query("DELETE FROM SDVXImportGroup")
    suspend fun deleteAllImportGroups()
}
