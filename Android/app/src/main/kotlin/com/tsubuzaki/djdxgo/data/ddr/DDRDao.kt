package com.tsubuzaki.djdxgo.data.ddr

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
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

    @Query("DELETE FROM DDRSongRecord")
    suspend fun deleteAllScoreData()

    @Query("DELETE FROM DDRImportGroup")
    suspend fun deleteAllImportGroups()
}
