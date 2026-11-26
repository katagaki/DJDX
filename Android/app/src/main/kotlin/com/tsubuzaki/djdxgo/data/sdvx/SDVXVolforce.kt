package com.tsubuzaki.djdxgo.data.sdvx

import kotlin.math.floor

object SDVXVolforce {

    private val gradeCoefficients = mapOf(
        SDVXGrade.S to 1.05, SDVXGrade.AAA_PLUS to 1.02, SDVXGrade.AAA to 1.0,
        SDVXGrade.AA_PLUS to 0.97, SDVXGrade.AA to 0.94, SDVXGrade.A_PLUS to 0.91,
        SDVXGrade.A to 0.88, SDVXGrade.B to 0.85, SDVXGrade.C to 0.82, SDVXGrade.D to 0.8
    )

    private val lampCoefficients = mapOf(
        SDVXClearType.PERFECT_ULTIMATE_CHAIN to 1.1, SDVXClearType.ULTIMATE_CHAIN to 1.05,
        SDVXClearType.EXCESSIVE_COMPLETE to 1.02, SDVXClearType.COMPLETE to 1.0,
        SDVXClearType.PLAYED to 0.5
    )

    fun total(records: List<SDVXSongRecord>): Double =
        records.map(::chartForce).sortedDescending().take(50).sum() / 1000.0

    fun chartForce(record: SDVXSongRecord): Int {
        val level = record.level.toDoubleOrNull() ?: 0.0
        if (level <= 0.0 || record.highScore <= 0) return 0
        val rate = minOf(record.highScore, 10_000_000) / 10_000_000.0
        val grade = gradeCoefficients[SDVXGrade.forScore(record.highScore)] ?: 0.0
        val lamp = SDVXClearType.fromValue(record.clearType)?.let { lampCoefficients[it] } ?: 0.0
        return floor(level * rate * grade * lamp * 20.0).toInt()
    }
}
