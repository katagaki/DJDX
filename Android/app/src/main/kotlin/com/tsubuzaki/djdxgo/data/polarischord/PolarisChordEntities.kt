package com.tsubuzaki.djdxgo.data.polarischord

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(tableName = "PolarisChordImportGroup")
data class PolarisChordImportGroup(
    @PrimaryKey val id: String,
    val importDate: Long,
    val version: Int?
)

@Entity(
    tableName = "PolarisChordSongRecord",
    indices = [Index("importGroupID")]
)
data class PolarisChordSongRecord(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val importGroupID: String,
    val title: String = "",
    val musicID: String = "",
    val category: String = "",
    val difficulty: String = "",
    val level: String = "",
    val achievementRate: String = "",
    val score: Int = 0,
    val clearType: String = "NO PLAY",
    val grade: String = "---"
)
