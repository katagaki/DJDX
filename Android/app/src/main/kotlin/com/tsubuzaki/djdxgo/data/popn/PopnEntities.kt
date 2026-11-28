package com.tsubuzaki.djdxgo.data.popn

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(tableName = "PopnImportGroup")
data class PopnImportGroup(
    @PrimaryKey val id: String,
    val importDate: Long,
    val version: Int?
)

@Entity(
    tableName = "PopnSongRecord",
    indices = [Index("importGroupID")]
)
data class PopnSongRecord(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val importGroupID: String,
    val title: String = "",
    val genre: String = "",
    val artist: String = "",
    val difficulty: String = "",
    val level: Int = 0,
    val score: Int = 0,
    val medal: String = PopnMedal.NO_PLAY.code,
    val rank: String = PopnRank.NONE.value
) {
    val medalEnum: PopnMedal
        get() = PopnMedal.fromCode(medal)

    val clearType: String
        get() = medalEnum.clearType.value

    val popnClassPoint: Double
        get() = PopnClass.point(level, score, medalEnum)
}
