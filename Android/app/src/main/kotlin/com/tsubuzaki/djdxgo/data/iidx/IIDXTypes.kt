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

enum class IIDXVersion(
    val number: Int,
    val marketingName: String,
    val lightColor: Long,
    val darkColor: Long
) {
    IIDX1ST_STYLE(1, "1st&substream", 0xFF000000, 0xFFC8C8C8),
    IIDX2ND_STYLE(2, "2nd style", 0xFFFED153, 0xFFFED153),
    IIDX3RD_STYLE(3, "3rd style", 0xFFEB0389, 0xFFF697D1),
    IIDX4TH_STYLE(4, "4th style", 0xFFE8161E, 0xFFD53921),
    IIDX5TH_STYLE(5, "5th style", 0xFF133891, 0xFFFE9114),
    IIDX6TH_STYLE(6, "6th style", 0xFFB4038F, 0xFF978DBE),
    IIDX7TH_STYLE(7, "7th style", 0xFF24292C, 0xFF92A4AE),
    IIDX8TH_STYLE(8, "8th style", 0xFFEE7F02, 0xFFF3810F),
    IIDX9TH_STYLE(9, "9th style", 0xFF231816, 0xFF94C8F4),
    IIDX10TH_STYLE(10, "10th style", 0xFF082258, 0xFFFF1B00),
    RED(11, "IIDX RED", 0xFFFF0000, 0xFFFF0000),
    HAPPY_SKY(12, "HAPPY SKY", 0xFF122274, 0xFF5AE5FA),
    DISTORTED(13, "DistorteD", 0xFF353B1B, 0xFFEFF136),
    GOLD(14, "GOLD", 0xFFBF9127, 0xFFCAA230),
    DJ_TROOPERS(15, "DJ TROOPERS", 0xFF874626, 0xFFB97958),
    EMPRESS(16, "EMPRESS", 0xFFBB0736, 0xFFFB218A),
    SIRIUS(17, "SIRIUS", 0xFF0B1459, 0xFF95E4F5),
    RESORT_ANTHEM(18, "Resort Anthem", 0xFFD81905, 0xFFFCF100),
    LINCLE(19, "Lincle", 0xFF00B0EB, 0xFF59C4F2),
    TRICORO(20, "tricoro", 0xFF004495, 0xFFFEF771),
    SPADA(21, "SPADA", 0xFFEA571D, 0xFFFB7737),
    PENDUAL(22, "PENDUAL", 0xFF561026, 0xFFF35FA4),
    COPULA(23, "copula", 0xFFFAA204, 0xFFFEE844),
    SINOBUZ(24, "SINOBUZ", 0xFF18252E, 0xFF6D8698),
    CANNON_BALLERS(25, "CANNON BALLERS", 0xFF008643, 0xFF00C364),
    ROOTAGE(26, "Rootage", 0xFF5D1500, 0xFFEAAC09),
    HEROIC_VERSE(27, "HEROIC VERSE", 0xFF5037C9, 0xFFE080EC),
    BISTROVER(28, "BISTROVER", 0xFF042192, 0xFF70D6E9),
    CAST_HOUR(29, "CastHour", 0xFFEF4003, 0xFFFEA559),
    RESIDENT(30, "RESIDENT", 0xFF002129, 0xFF7F9EA6),
    EPOLIS(31, "EPOLIS", 0xFF323232, 0xFFF0FE00),
    PINKY_CRUSH(32, "Pinky Crush", 0xFFF9578E, 0xFFFF61B2),
    SPARKLE_SHOWER(33, "Sparkle Shower", 0xFF438F52, 0xFFADE34D),
    ZINRAI(34, "ZINRAI", 0xFF8A2BE2, 0xFFC66DFF);

    companion object {
        val current = ZINRAI

        fun fromMarketingName(name: String): IIDXVersion? =
            entries.firstOrNull { it.marketingName == name }
    }
}

object IIDXVersionInfo {
    val NUMBER = IIDXVersion.current.number
    val MARKETING_NAME = IIDXVersion.current.marketingName

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
    val statusPageURL = "$EAGATE/game/2dx/$NUMBER/djdata/status.html"
    const val EAGATE_BASE_URL = EAGATE

    val bemaniWikiLatestVersionPageURL =
        "https://bemaniwiki.com/?beatmania+IIDX+34+ZINRAI/%E6%96%B0%E6%9B%B2%E3%83%AA%E3%82%B9%E3%83%88"
    val bemaniWikiExistingVersionsPageURL =
        "https://bemaniwiki.com/?beatmania+IIDX+34+ZINRAI/" +
            "%E6%97%A7%E6%9B%B2%E7%B7%8F%E3%83%8E%E3%83%BC%E3%83%84%E6%95%B0%E3%83%AA%E3%82%B9%E3%83%88"
}
