package com.tsubuzaki.djdxgo.data.iidx

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.RawQuery
import androidx.sqlite.db.SupportSQLiteQuery
import kotlinx.coroutines.flow.Flow

@Dao
interface IIDXDao {
    @Insert
    suspend fun insertImportGroup(group: IIDXImportGroup)

    @Insert
    suspend fun insertSongRecords(records: List<IIDXSongRecord>)

    @Query("SELECT * FROM IIDXImportGroup ORDER BY importDate DESC")
    fun importGroupsFlow(): Flow<List<IIDXImportGroup>>

    @Query("SELECT * FROM IIDXImportGroup WHERE iidxVersion = :version ORDER BY importDate DESC")
    fun importGroupsFlow(version: Int): Flow<List<IIDXImportGroup>>

    @Query("SELECT * FROM IIDXImportGroup ORDER BY importDate DESC")
    suspend fun importGroups(): List<IIDXImportGroup>

    @Query("SELECT * FROM IIDXImportGroup WHERE iidxVersion = :version ORDER BY importDate DESC")
    suspend fun importGroups(version: Int): List<IIDXImportGroup>

    @Query(
        "SELECT * FROM IIDXImportGroup WHERE iidxVersion = :version AND importDate >= :startOfDay " +
            "AND importDate < :startOfNextDay ORDER BY importDate LIMIT 1"
    )
    suspend fun importGroup(version: Int, startOfDay: Long, startOfNextDay: Long): IIDXImportGroup?

    @Query(
        "SELECT * FROM IIDXImportGroup WHERE iidxVersion = :version AND importDate < :date " +
            "ORDER BY importDate DESC LIMIT 1"
    )
    suspend fun closestImportGroupBefore(version: Int, date: Long): IIDXImportGroup?

    @Query("DELETE FROM IIDXSongRecord WHERE importGroupID = :groupID AND playType = :playType")
    suspend fun deleteSongRecords(groupID: String, playType: String)

    @Query("DELETE FROM IIDXSongRecord WHERE importGroupID = :groupID")
    suspend fun deleteAllSongRecords(groupID: String)

    @Query("DELETE FROM IIDXImportGroup WHERE id = :groupID")
    suspend fun deleteImportGroup(groupID: String)

    @Query("SELECT * FROM IIDXSongRecord WHERE importGroupID = :groupID AND playType = :playType ORDER BY title")
    suspend fun songRecords(groupID: String, playType: String): List<IIDXSongRecord>

    @Query("SELECT * FROM IIDXSongRecord WHERE title = :title AND playType = :playType ORDER BY id")
    suspend fun songRecordsForTitle(title: String, playType: String): List<IIDXSongRecord>

    @Query("SELECT * FROM IIDXSongRecord WHERE title = :title ORDER BY id")
    suspend fun songRecordsForTitle(title: String): List<IIDXSongRecord>

    @Query("DELETE FROM IIDXTowerEntry")
    suspend fun deleteAllTowerEntries()

    @Insert
    suspend fun insertTowerEntries(entries: List<IIDXTowerEntry>)

    @Query("SELECT * FROM IIDXTowerEntry ORDER BY playDate DESC")
    suspend fun towerEntries(): List<IIDXTowerEntry>

    @Query("DELETE FROM IIDXSongRecord")
    suspend fun deleteAllScoreData()

    @Query("DELETE FROM IIDXImportGroup")
    suspend fun deleteAllImportGroups()

    @RawQuery
    suspend fun levelAggregates(query: SupportSQLiteQuery): List<IIDXLevelAggregate>
}
