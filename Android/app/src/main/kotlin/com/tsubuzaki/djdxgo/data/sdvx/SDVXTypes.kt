package com.tsubuzaki.djdxgo.data.sdvx

import java.net.URLEncoder

enum class SDVXVersion(val number: Int, val slug: String, val marketingName: String) {
    NABLA(7, "vii", "NABLA");

    private val eagate = "https://p.eagate.573.jp"

    fun downloadPageURL(): String =
        "$eagate/game/sdvx/$slug/playdata/download/index.html?method=display"

    fun loginPageRedirectURL(): String {
        val path = URLEncoder.encode(
            "/game/sdvx/$slug/playdata/download/index.html?method=display",
            "UTF-8"
        )
        return "$eagate/gate/p/login.html?path=$path"
    }

    val errorPageURL: String
        get() = "$eagate/game/sdvx/$slug/error/index.html"

    companion object {
        fun fromNumber(number: Int): SDVXVersion =
            entries.firstOrNull { it.number == number } ?: NABLA
    }
}

enum class SDVXDifficulty(val value: String) {
    NOVICE("NOVICE"),
    ADVANCED("ADVANCED"),
    EXHAUST("EXHAUST"),
    INFINITE("INFINITE"),
    MAXIMUM("MAXIMUM"),
    GRAVITY("GRAVITY"),
    HEAVENLY("HEAVENLY"),
    VIVID("VIVID"),
    EXCEED("EXCEED"),
    NABLA("NABLA"),
    ULTIMATE("ULTIMATE");

    val abbreviation: String
        get() = when (this) {
            NOVICE -> "NOV"
            ADVANCED -> "ADV"
            EXHAUST -> "EXH"
            INFINITE -> "INF"
            MAXIMUM -> "MXM"
            GRAVITY -> "GRV"
            HEAVENLY -> "HVN"
            VIVID -> "VVD"
            EXCEED -> "XCD"
            NABLA -> "NBL"
            ULTIMATE -> "ULT"
        }

    val sdvxInSlot: String
        get() = when (this) {
            NOVICE -> "n"
            ADVANCED -> "a"
            EXHAUST -> "e"
            else -> "m"
        }

    companion object {
        fun fromValue(value: String): SDVXDifficulty? =
            entries.firstOrNull { it.value == value }
    }
}

enum class SDVXClearType(val value: String) {
    PERFECT_ULTIMATE_CHAIN("PERFECT ULTIMATE CHAIN"),
    ULTIMATE_CHAIN("ULTIMATE CHAIN"),
    EXCESSIVE_COMPLETE("EXCESSIVE COMPLETE"),
    COMPLETE("COMPLETE"),
    PLAYED("PLAYED"),
    NO_PLAY("NO PLAY");

    val abbreviation: String
        get() = when (this) {
            PERFECT_ULTIMATE_CHAIN -> "PUC"
            ULTIMATE_CHAIN -> "UC"
            EXCESSIVE_COMPLETE -> "EXC"
            COMPLETE -> "COMP"
            PLAYED -> "PLAY"
            NO_PLAY -> "NP"
        }

    companion object {
        // Best to worst.
        val sorted: List<SDVXClearType> = entries.toList()

        fun fromValue(value: String): SDVXClearType? =
            entries.firstOrNull { it.value == value }

        fun sortIndex(value: String): Int {
            val type = fromValue(value) ?: return sorted.size
            return sorted.indexOf(type)
        }
    }
}

enum class SDVXGrade(val value: String) {
    S("S"),
    AAA_PLUS("AAA+"),
    AAA("AAA"),
    AA_PLUS("AA+"),
    AA("AA"),
    A_PLUS("A+"),
    A("A"),
    B("B"),
    C("C"),
    D("D"),
    NONE("---");

    companion object {
        // Best to worst.
        val sorted: List<SDVXGrade> = entries.toList()

        fun fromValue(value: String): SDVXGrade? =
            entries.firstOrNull { it.value == value }

        fun sortIndex(value: String): Int {
            val grade = fromValue(value) ?: return sorted.size
            return sorted.indexOf(grade)
        }

        fun forScore(score: Int): SDVXGrade = when {
            score >= 9_900_000 -> S
            score >= 9_800_000 -> AAA_PLUS
            score >= 9_700_000 -> AAA
            score >= 9_500_000 -> AA_PLUS
            score >= 9_300_000 -> AA
            score >= 9_000_000 -> A_PLUS
            score >= 8_700_000 -> A
            score >= 7_500_000 -> B
            score >= 6_500_000 -> C
            score >= 1 -> D
            else -> NONE
        }
    }
}
