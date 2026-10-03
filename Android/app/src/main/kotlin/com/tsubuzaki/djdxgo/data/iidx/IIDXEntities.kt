package com.tsubuzaki.djdxgo.data.iidx

import androidx.room.Embedded
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(tableName = "IIDXImportGroup")
data class IIDXImportGroup(
    @PrimaryKey val id: String,
    val importDate: Long,
    val iidxVersion: Int?
)

data class IIDXLevelScore(
    val level: String = "",
    val difficulty: Int = 0,
    val score: Int = 0,
    val perfectGreatCount: Int = 0,
    val greatCount: Int = 0,
    val missCount: Int = 0,
    val clearType: String = "NO PLAY",
    val djLevel: String = "---"
)

@Entity(
    tableName = "IIDXSongRecord",
    indices = [Index("importGroupID", "playType")]
)
data class IIDXSongRecord(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val importGroupID: String,
    val version: String = "",
    val title: String = "",
    val genre: String = "",
    val artist: String = "",
    val playCount: Int = 0,
    val playType: String = "single",
    val lastPlayDate: Long = 0,
    @Embedded(prefix = "beginner_") val beginner: IIDXLevelScore = IIDXLevelScore(),
    @Embedded(prefix = "normal_") val normal: IIDXLevelScore = IIDXLevelScore(),
    @Embedded(prefix = "hyper_") val hyper: IIDXLevelScore = IIDXLevelScore(),
    @Embedded(prefix = "another_") val another: IIDXLevelScore = IIDXLevelScore(),
    @Embedded(prefix = "leggendaria_") val leggendaria: IIDXLevelScore = IIDXLevelScore()
) {
    fun slot(level: IIDXLevel): IIDXLevelScore = when (level) {
        IIDXLevel.BEGINNER -> beginner
        IIDXLevel.NORMAL -> normal
        IIDXLevel.HYPER -> hyper
        IIDXLevel.ANOTHER -> another
        IIDXLevel.LEGGENDARIA -> leggendaria
    }

    fun playedLevels(): List<Pair<IIDXLevel, IIDXLevelScore>> =
        IIDXLevel.entries.mapNotNull { level ->
            val score = slot(level)
            if (score.difficulty != 0) level to score else null
        }
}

@Entity(tableName = "IIDXTowerEntry")
data class IIDXTowerEntry(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val playDate: Long,
    val keyCount: Int = 0,
    val scratchCount: Int = 0
)

data class IIDXLevelAggregate(
    val groupID: String,
    val version: String,
    val difficulty: Int,
    val clearType: String,
    val djLevel: String,
    val hasScore: Boolean,
    val count: Int
)
