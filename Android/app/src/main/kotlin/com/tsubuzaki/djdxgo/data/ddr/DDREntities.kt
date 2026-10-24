package com.tsubuzaki.djdxgo.data.ddr

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(tableName = "DDRImportGroup")
data class DDRImportGroup(
    @PrimaryKey val id: String,
    val importDate: Long,
    val version: Int?
)

@Entity(
    tableName = "DDRSongRecord",
    indices = [Index("importGroupID")]
)
data class DDRSongRecord(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val importGroupID: String,
    val songIndex: String = "",
    val title: String = "",
    val style: String = "",
    val difficulty: String = "",
    val level: Int = 0,
    val score: Int = 0,
    val rank: String = "",
    val clearKind: String = "",
    val flareSkill: Int = 0,
    val flareRank: String = "",
    val jacketPath: String = ""
)
