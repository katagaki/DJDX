package com.tsubuzaki.djdxgo.data.popn

import java.net.URLEncoder
import kotlin.math.floor
import kotlin.math.min

object PopnVersionInfo {
    const val NUMBER = 29
    const val SLUG = "popn29"
    const val MARKETING_NAME = "High Cheers!!"
    const val ALL_VERSIONS_FILTER = "-1"

    private const val EAGATE = "https://p.eagate.573.jp"

    const val BASE_PATH = "/game/popn/$SLUG"
    val profilePageURL = "$EAGATE$BASE_PATH/playdata/index.html"
    val errorPagePrefix = "$EAGATE$BASE_PATH/error/"

    fun loginPageRedirectURL(): String {
        val path = URLEncoder.encode(profilePageURL, "UTF-8")
        return "$EAGATE/gate/p/login.html?path=$path"
    }
}

enum class PopnDifficulty(val value: String) {
    EASY("EASY"),
    NORMAL("NORMAL"),
    HYPER("HYPER"),
    EX("EX");

    val abbreviation: String
        get() = when (this) {
            EASY -> "E"
            NORMAL -> "N"
            HYPER -> "H"
            EX -> "EX"
        }

    companion object {
        fun fromValue(value: String): PopnDifficulty? = entries.firstOrNull { it.value == value }

        fun fromLabel(label: String): PopnDifficulty? = when (label.trim().uppercase()) {
            "EASY", "LIGHT" -> EASY
            "NORMAL" -> NORMAL
            "HYPER" -> HYPER
            "EX" -> EX
            else -> null
        }
    }
}

enum class PopnClearType(val value: String, val abbreviation: String) {
    PERFECT("PERFECT", "PFT"),
    FULL_COMBO("FULL COMBO", "FC"),
    CLEAR("CLEAR", "CLR"),
    EASY_CLEAR("EASY CLEAR", "EC"),
    ASSIST_CLEAR("ASSIST CLEAR", "AC"),
    FAILED("FAILED", "FAIL"),
    NO_PLAY("NO PLAY", "NP");

    companion object {
        val sorted: List<PopnClearType> = entries.toList()

        fun fromValue(value: String): PopnClearType? = entries.firstOrNull { it.value == value }
    }
}

enum class PopnMedal(val code: String, val clearType: PopnClearType, val shape: String) {
    PERFECT("a", PopnClearType.PERFECT, ""),
    FULL_COMBO_STAR("b", PopnClearType.FULL_COMBO, "★"),
    FULL_COMBO_DIAMOND("c", PopnClearType.FULL_COMBO, "◆"),
    FULL_COMBO_CIRCLE("d", PopnClearType.FULL_COMBO, "●"),
    CLEAR_STAR("e", PopnClearType.CLEAR, "★"),
    CLEAR_DIAMOND("f", PopnClearType.CLEAR, "◆"),
    CLEAR_CIRCLE("g", PopnClearType.CLEAR, "●"),
    EASY_CLEAR("k", PopnClearType.EASY_CLEAR, ""),
    ASSIST_CLEAR("l", PopnClearType.ASSIST_CLEAR, ""),
    FAILED_STAR("h", PopnClearType.FAILED, "★"),
    FAILED_DIAMOND("i", PopnClearType.FAILED, "◆"),
    FAILED_CIRCLE("j", PopnClearType.FAILED, "●"),
    NO_PLAY("none", PopnClearType.NO_PLAY, "");

    val abbreviation: String
        get() = clearType.abbreviation + shape

    val popnClassBonus: Int
        get() = when (clearType) {
            PopnClearType.PERFECT, PopnClearType.FULL_COMBO -> 5000
            PopnClearType.CLEAR, PopnClearType.EASY_CLEAR -> 3000
            else -> 0
        }

    companion object {
        fun fromCode(code: String): PopnMedal = entries.firstOrNull { it.code == code.lowercase() } ?: NO_PLAY

        fun sortIndex(code: String): Int = entries.indexOf(fromCode(code))
    }
}

enum class PopnRank(val value: String, val code: String) {
    S("S", "s"),
    AAA("AAA", "a3"),
    AA_PLUS("AA+", "a2_plus"),
    AA("AA", "a2"),
    A_PLUS("A+", "a1_plus"),
    A("A", "a1"),
    B_PLUS("B+", "b_plus"),
    B("B", "b"),
    C("C", "c"),
    D("D", "d"),
    E("E", "e"),
    NONE("---", "none");

    companion object {
        val sorted: List<PopnRank> = entries.filter { it != NONE }

        fun fromValue(value: String): PopnRank? = entries.firstOrNull { it.value == value }

        fun fromCode(code: String): PopnRank = entries.firstOrNull { it.code == code.lowercase() } ?: NONE
    }
}

object PopnClass {
    data class Tier(val minimum: Double, val name: String)

    val tiers = listOf(
        Tier(91.0, "神"),
        Tier(79.0, "仙人"),
        Tier(68.0, "将軍"),
        Tier(59.0, "アイドル"),
        Tier(46.0, "刑事"),
        Tier(34.0, "番長"),
        Tier(21.0, "小学生"),
        Tier(0.0, "にゃんこ")
    )

    private const val CHART_COUNT = 50

    fun point(level: Int, score: Int, medal: PopnMedal): Double {
        if (level <= 0 || score < 50000) return 0.0
        val raw = (10000.0 * level + score - 50000 + medal.popnClassBonus) / 5440.0
        return min(floor(raw * 100.0) / 100.0, 100.0)
    }

    fun value(records: List<PopnSongRecord>): Double {
        val top = records.map { it.popnClassPoint }.filter { it > 0 }.sortedDescending().take(CHART_COUNT)
        if (top.isEmpty()) return 0.0
        return floor(top.average() * 100.0) / 100.0
    }

    fun tier(value: Double): Tier = tiers.firstOrNull { value >= it.minimum } ?: tiers.last()
}
