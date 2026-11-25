package com.tsubuzaki.djdxgo.ui.tierlist

import androidx.compose.ui.graphics.Color
import com.tsubuzaki.djdxgo.AppContainer
import com.tsubuzaki.djdxgo.data.Game
import com.tsubuzaki.djdxgo.data.ddr.DDRPlayStyle
import com.tsubuzaki.djdxgo.data.iidx.IIDXLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordClearType
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordDifficulty
import com.tsubuzaki.djdxgo.data.sdvx.SDVXClearType
import com.tsubuzaki.djdxgo.data.sdvx.SDVXDifficulty
import com.tsubuzaki.djdxgo.ui.theme.DDRColors
import com.tsubuzaki.djdxgo.ui.theme.IIDXColors
import com.tsubuzaki.djdxgo.ui.theme.Palette
import com.tsubuzaki.djdxgo.ui.theme.PolarisChordColors
import com.tsubuzaki.djdxgo.ui.theme.SDVXColors

data class TierListChart(
    val id: String,
    val title: String,
    val level: String,
    val difficultyLabel: String,
    val difficultyColor: Color,
    val lampColor: Color,
    val grade: String,
    val gradeColor: Color,
    val iidxLevel: IIDXLevel? = null
)

val Game.tierListCode: String
    get() = when (this) {
        Game.IIDX_ARCADE -> "iidx"
        Game.SOUND_VOLTEX -> "sdvx"
        Game.POLARIS_CHORD -> "polarischord"
        Game.DANCE_DANCE_REVOLUTION -> "ddr"
    }

val Game.supportsTierListPlayType: Boolean
    get() = this == Game.IIDX_ARCADE || this == Game.DANCE_DANCE_REVOLUTION

fun gameForTierListCode(code: String): Game? = Game.entries.firstOrNull { it.tierListCode == code }

fun tierListChartID(title: String, difficulty: String): String = "$title|$difficulty"

fun tierListLevelSortKey(level: String): Pair<Int, String> =
    (level.takeWhile { it.isDigit() }.toIntOrNull() ?: 0) to level

private fun ddrRankDisplay(stem: String): String {
    if (stem.isEmpty()) return ""
    val parts = stem.split("_")
    val letter = parts.first().uppercase()
    return when (parts.getOrNull(1)) {
        "p" -> "$letter+"
        "m" -> "$letter-"
        else -> letter
    }
}

suspend fun loadTierListCharts(
    container: AppContainer,
    game: Game,
    playType: String,
    darkTheme: Boolean
): List<TierListChart> {
    val now = System.currentTimeMillis() / 1000L
    return when (game) {
        Game.IIDX_ARCADE -> {
            val type = if (playType == "DP") IIDXPlayType.DOUBLE else IIDXPlayType.SINGLE
            container.iidxRepository.songRecords(now, type).flatMap { record ->
                record.playedLevels().map { (level, score) ->
                    val djLevel = if (score.djLevel == "---") "" else score.djLevel
                    TierListChart(
                        id = tierListChartID(record.title, level.csvPrefix),
                        title = record.title,
                        level = score.difficulty.toString(),
                        difficultyLabel = level.code,
                        difficultyColor = IIDXColors.levelColor(level),
                        lampColor = IIDXColors.clearTypeColor(score.clearType),
                        grade = djLevel,
                        gradeColor = IIDXColors.djLevelColor(djLevel),
                        iidxLevel = level
                    )
                }
            }
        }
        Game.SOUND_VOLTEX -> container.sdvxRepository.songRecords(now)
            .filter { it.level.isNotEmpty() }
            .map { record ->
                val grade = if (record.grade == "---") "" else record.grade
                TierListChart(
                    id = tierListChartID(record.title, record.difficulty),
                    title = record.title,
                    level = record.level,
                    difficultyLabel = SDVXDifficulty.fromValue(record.difficulty)?.abbreviation.orEmpty(),
                    difficultyColor = SDVXColors.difficultyColor(record.difficulty),
                    lampColor = if (SDVXClearType.fromValue(record.clearType) == SDVXClearType.NO_PLAY) {
                        Palette.gray
                    } else {
                        SDVXColors.clearTypeColor(record.clearType)
                    },
                    grade = grade,
                    gradeColor = SDVXColors.gradeColor(grade, darkTheme)
                )
            }
        Game.POLARIS_CHORD -> container.polarisChordRepository.songRecords(now)
            .filter { it.level.isNotEmpty() }
            .map { record ->
                val grade = if (record.grade == "---") "" else record.grade
                TierListChart(
                    id = tierListChartID(record.title, record.difficulty),
                    title = record.title,
                    level = record.level,
                    difficultyLabel = PolarisChordDifficulty.fromValue(record.difficulty)?.abbreviation.orEmpty(),
                    difficultyColor = PolarisChordColors.difficultyColor(record.difficulty),
                    lampColor = if (PolarisChordClearType.fromValue(record.clearType) == null) {
                        Palette.gray
                    } else {
                        PolarisChordColors.clearTypeColor(record.clearType)
                    },
                    grade = grade,
                    gradeColor = PolarisChordColors.gradeColor(grade)
                )
            }
        Game.DANCE_DANCE_REVOLUTION -> {
            val style = if (playType == "DP") DDRPlayStyle.DOUBLE else DDRPlayStyle.SINGLE
            container.ddrRepository.songRecords(now, style)
                .filter { it.level > 0 }
                .map { record ->
                    TierListChart(
                        id = tierListChartID(record.title, record.difficulty),
                        title = record.title,
                        level = record.level.toString(),
                        difficultyLabel = record.difficulty.take(3),
                        difficultyColor = DDRColors.difficultyColor(record.difficulty),
                        lampColor = DDRColors.clearLampColor(record.clearKind.ifEmpty { "noclear" }, darkTheme),
                        grade = ddrRankDisplay(record.rank),
                        gradeColor = DDRColors.rankColor(record.rank, darkTheme)
                    )
                }
        }
    }
}

fun placeholderTierListChart(id: String, level: String, game: Game): TierListChart {
    val title = id.substringBefore("|")
    val difficulty = id.substringAfter("|", "")
    return TierListChart(
        id = id,
        title = title,
        level = level,
        difficultyLabel = difficulty.take(3),
        difficultyColor = Palette.gray,
        lampColor = Palette.gray.copy(alpha = 0.4f),
        grade = "",
        gradeColor = Palette.gray,
        iidxLevel = if (game == Game.IIDX_ARCADE) IIDXLevel.entries.firstOrNull { it.csvPrefix == difficulty } else null
    )
}

