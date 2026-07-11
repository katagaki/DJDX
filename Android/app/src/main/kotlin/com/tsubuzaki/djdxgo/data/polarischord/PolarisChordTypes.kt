package com.tsubuzaki.djdxgo.data.polarischord

import java.net.URLEncoder

object PolarisChordVersionInfo {
    const val NUMBER = 1
    const val SLUG = "pc"
    const val MARKETING_NAME = "ポラリスコード"

    private const val EAGATE = "https://p.eagate.573.jp"

    val musicDataPageURL = "$EAGATE/game/polarischord/$SLUG/playdata/music_data.html"

    fun loginPageRedirectURL(): String {
        val path = URLEncoder.encode("/game/polarischord/$SLUG/playdata/music_data.html", "UTF-8")
        return "$EAGATE/gate/p/login.html?path=$path"
    }
}

enum class PolarisChordDifficulty(val value: String, val typeCode: Int) {
    EASY("EASY", 0),
    NORMAL("NORMAL", 1),
    HARD("HARD", 2),
    INFLUENCE("INFLUENCE", 3),
    POLAR("POLAR", 4);

    val abbreviation: String
        get() = when (this) {
            EASY -> "ESY"
            NORMAL -> "NOR"
            HARD -> "HRD"
            INFLUENCE -> "INF"
            POLAR -> "PLR"
        }

    companion object {
        fun fromValue(value: String): PolarisChordDifficulty? =
            entries.firstOrNull { it.value == value }

        fun fromTypeCode(code: Int): PolarisChordDifficulty? =
            entries.firstOrNull { it.typeCode == code }
    }
}

enum class PolarisChordClearType(val value: String, val statusCode: Int) {
    ALL_PERFECT("ALL PERFECT", 4),
    FULL_COMBO("FULL COMBO", 3),
    SUCCESS("SUCCESS", 2),
    FAILED("FAILED", 1),
    NO_PLAY("NO PLAY", 0);

    val abbreviation: String
        get() = when (this) {
            ALL_PERFECT -> "AP"
            FULL_COMBO -> "FC"
            SUCCESS -> "CLEAR"
            FAILED -> "FAIL"
            NO_PLAY -> "NP"
        }

    companion object {
        // Best to worst.
        val sorted: List<PolarisChordClearType> = entries.toList()

        fun fromValue(value: String): PolarisChordClearType? =
            entries.firstOrNull { it.value == value }

        fun fromStatusCode(code: Int): PolarisChordClearType =
            entries.firstOrNull { it.statusCode == code } ?: NO_PLAY

        fun sortIndex(value: String): Int {
            val type = fromValue(value) ?: return sorted.size
            return sorted.indexOf(type)
        }
    }
}

enum class PolarisChordGrade(val value: String) {
    SSS_PLUS_PLUS("SSS++"),
    SSS_PLUS("SSS+"),
    SSS("SSS"),
    SS("SS"),
    S("S"),
    AAA("AAA"),
    AA("AA"),
    A("A"),
    B("B"),
    C("C"),
    D("D"),
    NONE("---");

    companion object {
        // Best to worst.
        val sorted: List<PolarisChordGrade> = entries.toList()

        fun fromValue(value: String): PolarisChordGrade? =
            entries.firstOrNull { it.value == value }

        fun sortIndex(value: String): Int {
            val grade = fromValue(value) ?: return sorted.size
            return sorted.indexOf(grade)
        }

        fun forAchievementRate(rateHundredths: Int): PolarisChordGrade = when {
            rateHundredths >= 10000 -> SSS_PLUS_PLUS
            rateHundredths >= 9951 -> SSS_PLUS
            rateHundredths >= 9901 -> SSS
            rateHundredths >= 9851 -> SS
            rateHundredths >= 9801 -> S
            rateHundredths >= 9501 -> AAA
            rateHundredths >= 9001 -> AA
            rateHundredths >= 8501 -> A
            rateHundredths >= 8001 -> B
            rateHundredths >= 7001 -> C
            rateHundredths >= 1 -> D
            else -> NONE
        }
    }
}
