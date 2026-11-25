package com.tsubuzaki.djdxgo.data.gitadora

import java.net.URLEncoder

object GITADORAVersionInfo {
    const val NUMBER = 2
    const val SLUG = "gitadora_galaxywave_delta"
    const val MARKETING_NAME = "GALAXY WAVE DELTA"

    private const val EAGATE = "https://p.eagate.573.jp"

    val playDataBaseURL = "$EAGATE/game/gfdm/$SLUG/p/playdata/"
    val profilePageURL = "${playDataBaseURL}profile.html"
    const val ERROR_PATH = "/game/gfdm/$SLUG/p/error/"

    fun skillPageURL(gameType: String, skillType: Int): String =
        "${playDataBaseURL}skill.html?gtype=$gameType&stype=$skillType"

    fun loginPageRedirectURL(): String {
        val path = URLEncoder.encode(profilePageURL, "UTF-8")
        return "$EAGATE/gate/p/login.html?path=$path"
    }
}

enum class GITADORAInstrument(val value: String, val gameType: String) {
    GUITAR("GUITAR", "gf"),
    BASS("BASS", "gf"),
    DRUM("DRUM", "dm");

    companion object {
        fun fromValue(value: String): GITADORAInstrument? = entries.firstOrNull { it.value == value }
    }
}

enum class GITADORADifficulty(val value: String) {
    BASIC("BASIC"),
    ADVANCED("ADVANCED"),
    EXTREME("EXTREME"),
    MASTER("MASTER");

    val abbreviation: String
        get() = when (this) {
            BASIC -> "BSC"
            ADVANCED -> "ADV"
            EXTREME -> "EXT"
            MASTER -> "MAS"
        }

    companion object {
        fun fromValue(value: String): GITADORADifficulty? = entries.firstOrNull { it.value == value }
    }
}

enum class GITADORAClearType(val value: String) {
    EXCELLENT("EXCELLENT"),
    FULL_COMBO("FULL COMBO"),
    CLEAR("CLEAR"),
    FAILED("FAILED"),
    NO_PLAY("NO PLAY");

    val abbreviation: String
        get() = when (this) {
            EXCELLENT -> "EXC"
            FULL_COMBO -> "FC"
            CLEAR -> "CLEAR"
            FAILED -> "FAIL"
            NO_PLAY -> "NP"
        }

    companion object {
        val sorted: List<GITADORAClearType> = entries.toList()

        fun fromValue(value: String): GITADORAClearType? = entries.firstOrNull { it.value == value }

        fun sortIndex(value: String): Int {
            val type = fromValue(value) ?: return sorted.size
            return sorted.indexOf(type)
        }
    }
}

enum class GITADORARank(val value: String) {
    SS("SS"),
    S("S"),
    A("A"),
    B("B"),
    C("C"),
    D("D"),
    E("E"),
    NONE("---");

    companion object {
        val sorted: List<GITADORARank> = entries.filter { it != NONE }

        fun fromValue(value: String): GITADORARank? = entries.firstOrNull { it.value == value }

        fun forAchievementRate(rate: Double): GITADORARank = when {
            rate >= 95.0 -> SS
            rate >= 80.0 -> S
            rate >= 73.0 -> A
            rate >= 63.0 -> B
            rate >= 53.0 -> C
            rate > 0.0 -> D
            else -> NONE
        }
    }
}
