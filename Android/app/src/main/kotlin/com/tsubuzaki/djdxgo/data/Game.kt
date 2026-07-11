package com.tsubuzaki.djdxgo.data

enum class Game(val id: Int) {
    IIDX_ARCADE(0),
    SOUND_VOLTEX(1),
    POLARIS_CHORD(3),
    DANCE_DANCE_REVOLUTION(4);

    val displayName: String
        get() = when (this) {
            IIDX_ARCADE -> "beatmania IIDX"
            SOUND_VOLTEX -> "SOUND VOLTEX"
            POLARIS_CHORD -> "ポラリスコード"
            DANCE_DANCE_REVOLUTION -> "DanceDanceRevolution"
        }

    val shortName: String
        get() = when (this) {
            IIDX_ARCADE -> "IIDX"
            SOUND_VOLTEX -> "SDVX"
            POLARIS_CHORD -> "ぽらりこ"
            DANCE_DANCE_REVOLUTION -> "DDR"
        }

    val supportsPlayType: Boolean
        get() = this == IIDX_ARCADE

    val supportsTower: Boolean
        get() = this == IIDX_ARCADE

    companion object {
        fun fromId(id: Int): Game = entries.firstOrNull { it.id == id } ?: IIDX_ARCADE
    }
}
