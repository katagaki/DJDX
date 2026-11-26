package com.tsubuzaki.djdxgo.data.importsummary

import com.tsubuzaki.djdxgo.data.Game

data class ImportSummary(
    val game: Game,
    val importDate: Long,
    val previousImportDate: Long?,
    val ratings: List<ImportSummaryRating>,
    val personalBests: List<ImportSummaryEntry>
)

data class ImportSummaryRating(
    val name: String,
    val previousValue: Double?,
    val value: Double,
    val fractionDigits: Int
) {
    val delta: Double?
        get() = previousValue?.let { value - it }
}

data class ImportSummaryChange(
    val previous: String?,
    val current: String
)

data class ImportSummaryEntry(
    val title: String,
    val chart: String,
    val difficulty: String,
    val levelValue: Double,
    val previousScore: Int?,
    val score: Int?,
    val lamp: ImportSummaryChange?,
    val grade: ImportSummaryChange?
)

internal fun isRankImprovement(previous: String?, latest: String, bestFirst: List<String>): Boolean {
    val latestIndex = bestFirst.indexOf(latest)
    if (latestIndex == -1) return false
    val previousIndex = previous?.let { bestFirst.indexOf(it) }?.takeIf { it != -1 } ?: bestFirst.size
    return latestIndex < previousIndex
}

internal val entryOrder: Comparator<ImportSummaryEntry> =
    compareByDescending<ImportSummaryEntry> { it.levelValue }.thenBy { it.title }
