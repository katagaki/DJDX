package com.tsubuzaki.djdxgo.data.iidx

import java.net.URLEncoder

enum class IIDXPlayType(val value: String) {
    SINGLE("single"),
    DOUBLE("double");

    val displayName: String
        get() = if (this == SINGLE) "SP" else "DP"

    val code: String
        get() = if (this == SINGLE) "SP" else "DP"

    companion object {
        fun fromValue(value: String): IIDXPlayType =
            entries.firstOrNull { it.value == value } ?: SINGLE
    }
}

enum class IIDXLevel(val code: String, val csvPrefix: String) {
    BEGINNER("B", "BEGINNER"),
    NORMAL("N", "NORMAL"),
    HYPER("H", "HYPER"),
    ANOTHER("A", "ANOTHER"),
    LEGGENDARIA("L", "LEGGENDARIA");

    companion object {
        fun fromCode(code: String): IIDXLevel? = entries.firstOrNull { it.code == code }
    }
}

enum class IIDXClearType(val value: String) {
    FULL_COMBO_CLEAR("FULLCOMBO CLEAR"),
    CLEAR("CLEAR"),
    EASY_CLEAR("EASY CLEAR"),
    ASSIST_CLEAR("ASSIST CLEAR"),
    HARD_CLEAR("HARD CLEAR"),
    EX_HARD_CLEAR("EX HARD CLEAR"),
    FAILED("FAILED"),
    NO_PLAY("NO PLAY");

    val abbreviation: String
        get() = when (this) {
            FULL_COMBO_CLEAR -> "F-COMBO"
            CLEAR -> "CLEAR"
            EASY_CLEAR -> "E-CLEAR"
            ASSIST_CLEAR -> "A-CLEAR"
            HARD_CLEAR -> "H-CLEAR"
            EX_HARD_CLEAR -> "EXH-CLEAR"
            FAILED -> "FAILED"
            NO_PLAY -> "NO PLAY"
        }

    companion object {
        // Best to worst.
        val sorted: List<IIDXClearType> = listOf(
            FULL_COMBO_CLEAR, CLEAR, EASY_CLEAR, ASSIST_CLEAR,
            HARD_CLEAR, EX_HARD_CLEAR, FAILED, NO_PLAY
        )

        val sortedWithoutNoPlay: List<IIDXClearType> = sorted.dropLast(1)

        fun fromValue(value: String): IIDXClearType? =
            entries.firstOrNull { it.value == value }

        fun sortIndex(value: String): Int {
            val type = fromValue(value) ?: return sorted.size
            return sorted.indexOf(type)
        }
    }
}

enum class IIDXDJLevel(val value: String) {
    AAA("AAA"),
    AA("AA"),
    A("A"),
    B("B"),
    C("C"),
    D("D"),
    E("E"),
    F("F"),
    NONE("---");

    companion object {
        // Worst to best (excluding NONE).
        val sorted: List<IIDXDJLevel> = listOf(F, E, D, C, B, A, AA, AAA)

        fun fromValue(value: String): IIDXDJLevel? =
            entries.firstOrNull { it.value == value }

        fun sortIndex(value: String): Int {
            val level = fromValue(value) ?: return -1
            return sorted.indexOf(level)
        }
    }
}

object IIDXVersionInfo {
    const val NUMBER = 33
    const val MARKETING_NAME = "SPARKLE SHOWER"

    private const val EAGATE = "https://p.eagate.573.jp"

    fun downloadPageURL(style: String): String =
        "$EAGATE/game/2dx/$NUMBER/djdata/score_download.html?style=$style"

    fun loginPageRedirectURL(style: String): String {
        val path = URLEncoder.encode(
            "/game/2dx/$NUMBER/djdata/score_download.html?style=$style",
            "UTF-8"
        )
        return "$EAGATE/gate/p/login.html?path=$path"
    }

    val errorPageURL = "$EAGATE/game/2dx/$NUMBER/error/error.html"
    val downloadPageBaseURL = "$EAGATE/game/2dx/$NUMBER/djdata/score_download.html"

    val bemaniWikiLatestVersionPageURL =
        "https://bemaniwiki.com/?beatmania+IIDX+33+Sparkle+Shower/%BF%B7%B6%CA%A5%EA%A5%B9%A5%C8"
    val bemaniWikiExistingVersionsPageURL =
        "https://bemaniwiki.com/?beatmania+IIDX+33+Sparkle+Shower/%B5%EC%B6%CA%C1%ED%A5%CE%A1%BC%A5%C4%BF%F4%A5%EA%A5%B9%A5%C8"
}
