package com.tsubuzaki.djdxgo.data.external

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "IIDXSong",
    indices = [Index("titleCompact", unique = true)]
)
data class IIDXSong(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val title: String = "",
    val titleCompact: String = "",
    val spBeginnerNoteCount: Int? = null,
    val spNormalNoteCount: Int? = null,
    val spHyperNoteCount: Int? = null,
    val spAnotherNoteCount: Int? = null,
    val spLeggendariaNoteCount: Int? = null,
    val dpBeginnerNoteCount: Int? = null,
    val dpNormalNoteCount: Int? = null,
    val dpHyperNoteCount: Int? = null,
    val dpAnotherNoteCount: Int? = null,
    val dpLeggendariaNoteCount: Int? = null,
    val time: String = "",
    val movie: String = "",
    val layer: String = "",
    val spBeginnerLevel: Int? = null,
    val spNormalLevel: Int? = null,
    val spHyperLevel: Int? = null,
    val spAnotherLevel: Int? = null,
    val spLeggendariaLevel: Int? = null,
    val dpNormalLevel: Int? = null,
    val dpHyperLevel: Int? = null,
    val dpAnotherLevel: Int? = null,
    val dpLeggendariaLevel: Int? = null
)

@Entity(
    tableName = "TextageChartViewerChart",
    indices = [Index("titleCompact", unique = true)]
)
data class TextageChartViewerChart(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val songId: String = "",
    val version: Int = 0,
    val title: String = "",
    val titleCompact: String = "",
    val spBeginner: Int = 0,
    val spNormal: Int = 0,
    val spHyper: Int = 0,
    val spAnother: Int = 0,
    val spLeggendaria: Int = 0,
    val dpBeginner: Int = 0,
    val dpNormal: Int = 0,
    val dpHyper: Int = 0,
    val dpAnother: Int = 0,
    val dpLeggendaria: Int = 0
)

@Entity(
    tableName = "SDVXInChart",
    indices = [Index(value = ["titleCompact", "slot"], unique = true)]
)
data class SDVXInChart(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val code: String = "",
    val slot: String = "",
    val title: String = "",
    val titleCompact: String = "",
    val level: Int = 0
) {
    val pageURL: String
        get() = "https://sdvx.in/${code.take(2)}/$code$slot.htm"
}

@Entity(
    tableName = "NotesRadar",
    indices = [Index(value = ["title", "playType", "difficulty"], unique = true)]
)
data class NotesRadarEntry(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val title: String = "",
    val titleCompact: String = "",
    val playType: String = "",
    val difficulty: Int = 0,
    val noteCount: Int = 0,
    val notes: Double = 0.0,
    val chord: Double = 0.0,
    val peak: Double = 0.0,
    val charge: Double = 0.0,
    val scratch: Double = 0.0,
    val soflan: Double = 0.0
) {
    fun sum(): Double = notes + chord + peak + charge + scratch + soflan
}

@Entity(tableName = "DDRSongMeta")
data class DDRSongMeta(
    @PrimaryKey val titleCompact: String,
    val title: String = "",
    val version: Int = 0,
    val spBeginner: Int = 0,
    val spBasic: Int = 0,
    val spDifficult: Int = 0,
    val spExpert: Int = 0,
    val spChallenge: Int = 0,
    val dpBasic: Int = 0,
    val dpDifficult: Int = 0,
    val dpExpert: Int = 0,
    val dpChallenge: Int = 0
)
