package com.tsubuzaki.djdxgo.data.sdvx

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(tableName = "SDVXImportGroup")
data class SDVXImportGroup(
    @PrimaryKey val id: String,
    val importDate: Long,
    val version: Int?
)

@Entity(
    tableName = "SDVXSongRecord",
    indices = [Index("importGroupID")]
)
data class SDVXSongRecord(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val importGroupID: String,
    val title: String = "",
    val difficulty: String = "",
    val level: String = "",
    val clearType: String = "NO PLAY",
    val grade: String = "---",
    val highScore: Int = 0,
    val exScore: Int = 0,
    val playCount: Int = 0,
    val clearCount: Int = 0,
    val ultimateChainCount: Int = 0,
    val perfectCount: Int = 0
)
