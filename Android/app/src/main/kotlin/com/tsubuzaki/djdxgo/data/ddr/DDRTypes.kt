package com.tsubuzaki.djdxgo.data.ddr

import java.net.URLEncoder

object DDRVersionInfo {
    const val NUMBER = 1
    const val SLUG = "ddrworld"
    const val MARKETING_NAME = "DDR WORLD"
    const val WORLD_VERSION_NUMBER = 20

    private const val EAGATE = "https://p.eagate.573.jp"

    val musicDataSinglePageURL =
        "$EAGATE/game/ddr/$SLUG/playdata/music_data_single.html"

    fun loginPageRedirectURL(): String {
        val path = URLEncoder.encode(
            "/game/ddr/$SLUG/playdata/music_data_single.html?offset=0&filter=0&display=score",
            "UTF-8"
        )
        return "$EAGATE/gate/p/login.html?path=$path"
    }

    val errorPageURL = "$EAGATE/game/ddr/$SLUG/error/"

    val profilePageURL = "$EAGATE/game/ddr/$SLUG/playdata/index.html"

    val bemaniWikiNewSongsPageURL =
        "https://bemaniwiki.com/?DanceDanceRevolution+WORLD/%E6%96%B0%E6%9B%B2%E3%83%AA%E3%82%B9%E3%83%88"
    val bemaniWikiOldSongsPageURL =
        "https://bemaniwiki.com/?DanceDanceRevolution+WORLD/%E6%97%A7%E6%9B%B2%E3%83%AA%E3%82%B9%E3%83%88"
}

enum class DDRPlayStyle(val value: String) {
    SINGLE("SINGLE"),
    DOUBLE("DOUBLE");

    val displayName: String
        get() = if (this == SINGLE) "SP" else "DP"

    companion object {
        fun fromValue(value: String): DDRPlayStyle =
            entries.firstOrNull { it.value == value } ?: SINGLE
    }
}

enum class DDRDifficulty(val value: String) {
    BEGINNER("BEGINNER"),
    BASIC("BASIC"),
    DIFFICULT("DIFFICULT"),
    EXPERT("EXPERT"),
    CHALLENGE("CHALLENGE");

    companion object {
        fun fromValue(value: String): DDRDifficulty? =
            entries.firstOrNull { it.value == value }

        fun fromIndex(index: Int): DDRDifficulty? = entries.getOrNull(index)
    }
}

object DDRClearLamp {
    // Best to worst.
    val order = listOf("marv", "perf", "great", "good", "li4clear", "clear", "assist", "fail")

    fun sortIndex(stem: String): Int {
        val index = order.indexOf(stem)
        return if (index == -1) order.size else index
    }

    fun display(stem: String): String = when (stem) {
        "marv" -> "MFC"
        "perf" -> "PFC"
        "great" -> "GFC"
        "good" -> "FC"
        "li4clear" -> "LIFE4"
        "clear" -> "CLEAR"
        "assist" -> "ASSIST"
        "fail" -> "FAILED"
        "noclear" -> "NO CLEAR"
        else -> stem.uppercase()
    }
}

object DDRRank {
    // Best to worst.
    val order = listOf(
        "aaa", "aa_p", "aa", "aa_m", "a_p", "a", "a_m",
        "b_p", "b", "b_m", "c_p", "c", "c_m", "d_p", "d", "e"
    )

    fun sortIndex(stem: String): Int {
        val index = order.indexOf(stem)
        return if (index == -1) order.size else index
    }

    fun display(stem: String): String =
        stem.replace("_p", "+").replace("_m", "-").uppercase()
}
