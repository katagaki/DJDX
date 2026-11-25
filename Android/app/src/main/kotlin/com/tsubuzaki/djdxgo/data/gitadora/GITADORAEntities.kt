package com.tsubuzaki.djdxgo.data.gitadora

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(tableName = "GITADORAImportGroup")
data class GITADORAImportGroup(
    @PrimaryKey val id: String,
    val importDate: Long,
    val version: Int?
)

@Entity(
    tableName = "GITADORASongRecord",
    indices = [Index("importGroupID")]
)
data class GITADORASongRecord(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val importGroupID: String,
    val title: String = "",
    val instrument: String = "",
    val difficulty: String = "",
    val level: String = "",
    val achievementRate: String = "",
    val score: Int = 0,
    val clearType: String = "NO PLAY",
    val rank: String = "---"
) {
    val levelValue: Double
        get() = level.toDoubleOrNull() ?: 0.0

    val levelBucket: String
        get() = if (levelValue > 0) levelValue.toInt().toString() else ""

    val achievementRateValue: Double
        get() = achievementRate.toDoubleOrNull() ?: 0.0

    val skillValue: Double
        get() = kotlin.math.floor(levelValue * achievementRateValue * 20.0) / 100.0
}
