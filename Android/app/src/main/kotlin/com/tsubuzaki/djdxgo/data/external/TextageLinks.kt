package com.tsubuzaki.djdxgo.data.external

import com.tsubuzaki.djdxgo.data.iidx.IIDXLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType

enum class IIDXPlaySide { SIDE_1P, SIDE_2P, NOT_APPLICABLE }

private const val BASE36 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

private fun textageFolder(version: Int): String = if (version == 35) "s" else version.toString()

fun TextageChart.level(level: IIDXLevel, playType: IIDXPlayType): Int = when (playType) {
    IIDXPlayType.SINGLE -> when (level) {
        IIDXLevel.NORMAL -> spNormal
        IIDXLevel.HYPER -> spHyper
        IIDXLevel.ANOTHER -> spAnother
        IIDXLevel.LEGGENDARIA -> spLeggendaria
        IIDXLevel.BEGINNER -> 0
    }
    IIDXPlayType.DOUBLE -> when (level) {
        IIDXLevel.NORMAL -> dpNormal
        IIDXLevel.HYPER -> dpHyper
        IIDXLevel.ANOTHER -> dpAnother
        IIDXLevel.LEGGENDARIA -> dpLeggendaria
        IIDXLevel.BEGINNER -> 0
    }
}

fun TextageChart.pageURL(level: IIDXLevel, playType: IIDXPlayType, playSide: IIDXPlaySide): String? {
    val levelValue = level(level, playType)
    if (levelValue <= 0 || levelValue >= BASE36.length) return null
    val difficultyChar = when (level) {
        IIDXLevel.NORMAL -> "N"
        IIDXLevel.HYPER -> "H"
        IIDXLevel.ANOTHER -> "A"
        IIDXLevel.LEGGENDARIA -> "X"
        IIDXLevel.BEGINNER -> return null
    }
    val sideChar = when (playType) {
        IIDXPlayType.DOUBLE -> "D"
        IIDXPlayType.SINGLE -> if (playSide == IIDXPlaySide.SIDE_2P) "2" else "1"
    }
    val query = "$sideChar$difficultyChar${BASE36[levelValue]}00"
    return "https://textage.cc/score/${textageFolder(version)}/$tag.html?$query"
}

fun TextageChartViewerChart.level(level: IIDXLevel, playType: IIDXPlayType): Int = when (playType) {
    IIDXPlayType.SINGLE -> when (level) {
        IIDXLevel.BEGINNER -> spBeginner
        IIDXLevel.NORMAL -> spNormal
        IIDXLevel.HYPER -> spHyper
        IIDXLevel.ANOTHER -> spAnother
        IIDXLevel.LEGGENDARIA -> spLeggendaria
    }
    IIDXPlayType.DOUBLE -> when (level) {
        IIDXLevel.BEGINNER -> dpBeginner
        IIDXLevel.NORMAL -> dpNormal
        IIDXLevel.HYPER -> dpHyper
        IIDXLevel.ANOTHER -> dpAnother
        IIDXLevel.LEGGENDARIA -> dpLeggendaria
    }
}

fun TextageChartViewerChart.pageURL(level: IIDXLevel, playType: IIDXPlayType): String? {
    if (level(level, playType) <= 0) return null
    val difficultyCode = when (level) {
        IIDXLevel.BEGINNER -> "b"
        IIDXLevel.NORMAL -> "n"
        IIDXLevel.HYPER -> "h"
        IIDXLevel.ANOTHER -> "a"
        IIDXLevel.LEGGENDARIA -> "l"
    }
    val playTypeCode = if (playType == IIDXPlayType.SINGLE) "sp" else "dp"
    return "https://textage-chart-viewer.vercel.app/chart/${textageFolder(version)}/$songId/$difficultyCode/$playTypeCode"
}
