package com.tsubuzaki.djdxgo.data.sdvx

import com.tsubuzaki.djdxgo.data.analytics.RatingPool
import kotlin.math.floor

object SDVXVolforce {
    const val CHART_LIMIT = 50

    val gradeThresholds = listOf(
        SDVXGrade.C to 6_500_000, SDVXGrade.B to 7_500_000, SDVXGrade.A to 8_700_000,
        SDVXGrade.A_PLUS to 9_000_000, SDVXGrade.AA to 9_300_000, SDVXGrade.AA_PLUS to 9_500_000,
        SDVXGrade.AAA to 9_700_000, SDVXGrade.AAA_PLUS to 9_800_000, SDVXGrade.S to 9_900_000
    )

    private val gradeCoefficients = mapOf(
        SDVXGrade.S to 105, SDVXGrade.AAA_PLUS to 102, SDVXGrade.AAA to 100, SDVXGrade.AA_PLUS to 97,
        SDVXGrade.AA to 94, SDVXGrade.A_PLUS to 91, SDVXGrade.A to 88, SDVXGrade.B to 85,
        SDVXGrade.C to 82, SDVXGrade.D to 80
    )

    private val lampCoefficients = mapOf(
        SDVXClearType.PERFECT_ULTIMATE_CHAIN.value to 110,
        SDVXClearType.ULTIMATE_CHAIN.value to 105,
        SDVXClearType.EXCESSIVE_COMPLETE.value to 102,
        SDVXClearType.COMPLETE.value to 100,
        SDVXClearType.PLAYED.value to 50
    )

    fun total(records: List<SDVXSongRecord>): Double =
        RatingPool(records.map(::chartForce), CHART_LIMIT).total / 1000.0

    fun grade(score: Int): SDVXGrade = when {
        score <= 0 -> SDVXGrade.NONE
        else -> gradeThresholds.lastOrNull { score >= it.second }?.first ?: SDVXGrade.D
    }

    fun force(level: Double, score: Int, clearType: String): Int {
        if (level <= 0.0 || score <= 0) return 0
        val capped = minOf(score, 10_000_000)
        val value = level * capped * (gradeCoefficients[grade(capped)] ?: 0) *
            (lampCoefficients[clearType] ?: 0) * 20.0 / 10_000_000.0 / 10_000.0
        return floor(value + 1e-9).toInt()
    }

    fun chartForce(record: SDVXSongRecord): Int =
        force(record.level.toDoubleOrNull() ?: 0.0, record.highScore, record.clearType)
}
