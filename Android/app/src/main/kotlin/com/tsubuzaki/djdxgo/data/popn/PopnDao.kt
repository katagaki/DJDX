package com.tsubuzaki.djdxgo.data.popn

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface PopnDao {
    @Insert
    suspend fun insertImportGroup(group: PopnImportGroup)

    @Insert
    suspend fun insertSongRecords(records: List<PopnSongRecord>)

    @Query("SELECT * FROM PopnImportGroup ORDER BY importDate DESC")
    fun importGroupsFlow(): Flow<List<PopnImportGroup>>

    @Query("SELECT * FROM PopnImportGroup ORDER BY importDate DESC")
    suspend fun importGroups(): List<PopnImportGroup>

    @Query(
        "SELECT * FROM PopnImportGroup WHERE importDate >= :startOfDay AND importDate < :startOfNextDay LIMIT 1"
    )
    suspend fun importGroup(startOfDay: Long, startOfNextDay: Long): PopnImportGroup?

    @Query(
        "SELECT * FROM PopnImportGroup WHERE importDate < :date ORDER BY importDate DESC LIMIT 1"
    )
    suspend fun closestImportGroupBefore(date: Long): PopnImportGroup?

    @Query("DELETE FROM PopnSongRecord WHERE importGroupID = :groupID")
    suspend fun deleteSongRecords(groupID: String)

    @Query("DELETE FROM PopnImportGroup WHERE id = :groupID")
    suspend fun deleteImportGroup(groupID: String)

    @Query("SELECT * FROM PopnSongRecord WHERE importGroupID = :groupID ORDER BY title")
    suspend fun songRecords(groupID: String): List<PopnSongRecord>

    @Query("SELECT * FROM PopnSongRecord WHERE importGroupID = :groupID AND title = :title ORDER BY id")
    suspend fun songRecordsForTitle(groupID: String, title: String): List<PopnSongRecord>

    @Query("DELETE FROM PopnSongRecord")
    suspend fun deleteAllScoreData()

    @Query("DELETE FROM PopnImportGroup")
    suspend fun deleteAllImportGroups()
}
