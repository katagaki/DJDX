package com.tsubuzaki.djdxgo.data.gitadora

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface GITADORADao {
    @Insert
    suspend fun insertImportGroup(group: GITADORAImportGroup)

    @Insert
    suspend fun insertSongRecords(records: List<GITADORASongRecord>)

    @Query("SELECT * FROM GITADORAImportGroup ORDER BY importDate DESC")
    fun importGroupsFlow(): Flow<List<GITADORAImportGroup>>

    @Query("SELECT * FROM GITADORAImportGroup ORDER BY importDate DESC")
    suspend fun importGroups(): List<GITADORAImportGroup>

    @Query(
        "SELECT * FROM GITADORAImportGroup WHERE importDate >= :startOfDay AND importDate < :startOfNextDay LIMIT 1"
    )
    suspend fun importGroup(startOfDay: Long, startOfNextDay: Long): GITADORAImportGroup?

    @Query(
        "SELECT * FROM GITADORAImportGroup WHERE importDate < :date ORDER BY importDate DESC LIMIT 1"
    )
    suspend fun closestImportGroupBefore(date: Long): GITADORAImportGroup?

    @Query("DELETE FROM GITADORASongRecord WHERE importGroupID = :groupID")
    suspend fun deleteSongRecords(groupID: String)

    @Query("DELETE FROM GITADORAImportGroup WHERE id = :groupID")
    suspend fun deleteImportGroup(groupID: String)

    @Query("SELECT * FROM GITADORASongRecord WHERE importGroupID = :groupID ORDER BY title")
    suspend fun songRecords(groupID: String): List<GITADORASongRecord>

    @Query("DELETE FROM GITADORASongRecord")
    suspend fun deleteAllScoreData()

    @Query("DELETE FROM GITADORAImportGroup")
    suspend fun deleteAllImportGroups()
}
