package com.tsubuzaki.djdxgo.data.external

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction

@Dao
interface ExternalDataDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertIIDXSongs(songs: List<IIDXSong>)

    @Query("DELETE FROM IIDXSong")
    suspend fun deleteAllIIDXSongs()

    @Query("SELECT * FROM IIDXSong WHERE titleCompact = :titleCompact LIMIT 1")
    suspend fun iidxSong(titleCompact: String): IIDXSong?

    @Query("SELECT * FROM IIDXSong")
    suspend fun allIIDXSongs(): List<IIDXSong>

    @Query("SELECT COUNT(*) FROM IIDXSong")
    suspend fun iidxSongCount(): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTextageCharts(charts: List<TextageChart>)

    @Query("DELETE FROM TextageChart")
    suspend fun deleteAllTextageCharts()

    @Query("SELECT * FROM TextageChart WHERE titleCompact = :titleCompact LIMIT 1")
    suspend fun textageChart(titleCompact: String): TextageChart?

    @Query("SELECT COUNT(*) FROM TextageChart")
    suspend fun textageChartCount(): Int

    @Transaction
    suspend fun replaceTextageCharts(charts: List<TextageChart>) {
        deleteAllTextageCharts()
        insertTextageCharts(charts)
    }

    @Transaction
    suspend fun replaceTextageChartViewerCharts(charts: List<TextageChartViewerChart>) {
        deleteAllTextageChartViewerCharts()
        insertTextageChartViewerCharts(charts)
    }

    @Transaction
    suspend fun replaceSDVXInCharts(charts: List<SDVXInChart>) {
        deleteAllSDVXInCharts()
        insertSDVXInCharts(charts)
    }

    @Transaction
    suspend fun replaceIIDXSongs(songs: List<IIDXSong>) {
        deleteAllIIDXSongs()
        insertIIDXSongs(songs)
    }

    @Transaction
    suspend fun replaceNotesRadarEntries(entries: List<NotesRadarEntry>) {
        deleteAllNotesRadarEntries()
        insertNotesRadarEntries(entries)
    }

    @Transaction
    suspend fun replaceDDRSongMetas(metas: List<DDRSongMeta>) {
        deleteAllDDRSongMetas()
        insertDDRSongMetas(metas)
    }


    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTextageChartViewerCharts(charts: List<TextageChartViewerChart>)

    @Query("DELETE FROM TextageChartViewerChart")
    suspend fun deleteAllTextageChartViewerCharts()

    @Query("SELECT * FROM TextageChartViewerChart WHERE titleCompact = :titleCompact LIMIT 1")
    suspend fun textageChartViewerChart(titleCompact: String): TextageChartViewerChart?

    @Query("SELECT COUNT(*) FROM TextageChartViewerChart")
    suspend fun textageChartViewerChartCount(): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSDVXInCharts(charts: List<SDVXInChart>)

    @Query("DELETE FROM SDVXInChart")
    suspend fun deleteAllSDVXInCharts()

    @Query("SELECT * FROM SDVXInChart WHERE titleCompact = :titleCompact AND slot = :slot LIMIT 1")
    suspend fun sdvxInChart(titleCompact: String, slot: String): SDVXInChart?

    @Query("SELECT COUNT(*) FROM SDVXInChart")
    suspend fun sdvxInChartCount(): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertNotesRadarEntries(entries: List<NotesRadarEntry>)

    @Query("DELETE FROM NotesRadar")
    suspend fun deleteAllNotesRadarEntries()

    @Query("SELECT * FROM NotesRadar WHERE titleCompact = :titleCompact AND playType = :playType AND difficulty = :difficulty LIMIT 1")
    suspend fun notesRadar(titleCompact: String, playType: String, difficulty: Int): NotesRadarEntry?

    @Query("SELECT * FROM NotesRadar WHERE playType = :playType")
    suspend fun notesRadarEntries(playType: String): List<NotesRadarEntry>

    @Query("SELECT COUNT(*) FROM NotesRadar")
    suspend fun notesRadarCount(): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDDRSongMetas(metas: List<DDRSongMeta>)

    @Query("DELETE FROM DDRSongMeta")
    suspend fun deleteAllDDRSongMetas()

    @Query("SELECT * FROM DDRSongMeta WHERE titleCompact = :titleCompact LIMIT 1")
    suspend fun ddrSongMeta(titleCompact: String): DDRSongMeta?

    @Query("SELECT * FROM DDRSongMeta")
    suspend fun allDDRSongMetas(): List<DDRSongMeta>

    @Query("SELECT COUNT(*) FROM DDRSongMeta")
    suspend fun ddrSongMetaCount(): Int
}
