package com.tsubuzaki.djdxgo.data.polarischord

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface PolarisChordDao {
    @Insert
    suspend fun insertImportGroup(group: PolarisChordImportGroup)

    @Insert
    suspend fun insertSongRecords(records: List<PolarisChordSongRecord>)

    @Query("SELECT * FROM PolarisChordImportGroup ORDER BY importDate DESC")
    fun importGroupsFlow(): Flow<List<PolarisChordImportGroup>>

    @Query("SELECT * FROM PolarisChordImportGroup ORDER BY importDate DESC")
    suspend fun importGroups(): List<PolarisChordImportGroup>

    @Query(
        "SELECT * FROM PolarisChordImportGroup WHERE importDate >= :startOfDay AND importDate < :startOfNextDay LIMIT 1"
    )
    suspend fun importGroup(startOfDay: Long, startOfNextDay: Long): PolarisChordImportGroup?

    @Query(
        "SELECT * FROM PolarisChordImportGroup WHERE importDate < :date ORDER BY importDate DESC LIMIT 1"
    )
    suspend fun closestImportGroupBefore(date: Long): PolarisChordImportGroup?

    @Query("DELETE FROM PolarisChordSongRecord WHERE importGroupID = :groupID")
    suspend fun deleteSongRecords(groupID: String)

    @Query("DELETE FROM PolarisChordImportGroup WHERE id = :groupID")
    suspend fun deleteImportGroup(groupID: String)

    @Query("SELECT * FROM PolarisChordSongRecord WHERE importGroupID = :groupID ORDER BY title")
    suspend fun songRecords(groupID: String): List<PolarisChordSongRecord>

    @Query("SELECT * FROM PolarisChordSongRecord WHERE importGroupID = :groupID AND title = :title ORDER BY id")
    suspend fun songRecordsForTitle(groupID: String, title: String): List<PolarisChordSongRecord>

    @Query("DELETE FROM PolarisChordSongRecord")
    suspend fun deleteAllScoreData()

    @Query("DELETE FROM PolarisChordImportGroup")
    suspend fun deleteAllImportGroups()
}
