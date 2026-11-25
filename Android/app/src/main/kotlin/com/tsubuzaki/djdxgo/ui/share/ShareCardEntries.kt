package com.tsubuzaki.djdxgo.ui.share

import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import com.tsubuzaki.djdxgo.data.ddr.DDRClearLamp
import com.tsubuzaki.djdxgo.data.ddr.DDRPlayStyle
import com.tsubuzaki.djdxgo.data.ddr.DDRRank
import com.tsubuzaki.djdxgo.data.ddr.DDRSongRecord
import com.tsubuzaki.djdxgo.data.iidx.IIDXClearType
import com.tsubuzaki.djdxgo.data.iidx.IIDXLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXLevelScore
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import com.tsubuzaki.djdxgo.data.iidx.IIDXSongRecord
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordClearType
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordGrade
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordSongRecord
import com.tsubuzaki.djdxgo.data.profile.DDRProfile
import com.tsubuzaki.djdxgo.data.profile.IIDXProfile
import com.tsubuzaki.djdxgo.data.profile.PolarisChordProfile
import com.tsubuzaki.djdxgo.data.profile.SDVXProfile
import com.tsubuzaki.djdxgo.data.sdvx.SDVXClearType
import com.tsubuzaki.djdxgo.data.sdvx.SDVXDifficulty
import com.tsubuzaki.djdxgo.data.sdvx.SDVXGrade
import com.tsubuzaki.djdxgo.data.sdvx.SDVXSongRecord
import com.tsubuzaki.djdxgo.ui.games.scoreGradientBrush
import com.tsubuzaki.djdxgo.ui.theme.DDRColors
import com.tsubuzaki.djdxgo.ui.theme.IIDXColors
import com.tsubuzaki.djdxgo.ui.theme.PolarisChordColors
import com.tsubuzaki.djdxgo.ui.theme.SDVXColors
import java.util.Locale

fun iidxShareCardEntry(
    record: IIDXSongRecord,
    level: IIDXLevel,
    score: IIDXLevelScore,
    scoreRate: Float?
): ShareCardEntry {
    val metrics = buildList {
        if (score.score != 0) {
            if (score.djLevel.isNotEmpty() && score.djLevel != "---") {
                add(ShareCardMetric(score.djLevel, IIDXColors.djLevelBrush(score.djLevel)))
            }
            if (scoreRate != null) {
                add(ShareCardMetric(
                    String.format(Locale.ROOT, "%.1f%%", scoreRate * 100f),
                    SolidColor(Color.White.copy(alpha = 0.7f))
                ))
            }
            add(ShareCardMetric(score.score.toString(), SolidColor(IIDXColors.scoreColor)))
        }
    }
    val lamp = if (IIDXClearType.fromValue(score.clearType) == IIDXClearType.FULL_COMBO_CLEAR) {
        IIDXColors.fullComboLampBrush
    } else {
        SolidColor(IIDXColors.lampColor(score.clearType, darkTheme = true))
    }
    return ShareCardEntry(
        title = record.title,
        subtitle = record.artist,
        lamp = lamp,
        levelText = score.difficulty.toString(),
        difficultyText = level.csvPrefix,
        difficultyColor = IIDXColors.levelColor(level),
        metrics = metrics
    )
}

fun SDVXSongRecord.toShareCardEntry(): ShareCardEntry {
    val clearType = SDVXClearType.fromValue(clearType)
    val metrics = buildList {
        val grade = SDVXGrade.fromValue(grade)
        if (grade != null && grade != SDVXGrade.NONE) {
            add(ShareCardMetric(this@toShareCardEntry.grade, SDVXColors.gradeBrush))
        }
        if (highScore != 0) {
            add(ShareCardMetric(highScore.toString(), SDVXColors.scoreBrush))
        }
        add(ShareCardMetric(
            clearType?.abbreviation ?: this@toShareCardEntry.clearType,
            SolidColor(SDVXColors.clearTypeColor(this@toShareCardEntry.clearType))
        ))
    }
    return ShareCardEntry(
        title = title,
        lamp = lampBrush(
            clearType == null || clearType == SDVXClearType.NO_PLAY,
            SDVXColors.clearTypeColor(this.clearType)
        ),
        levelText = level,
        difficultyText = SDVXDifficulty.fromValue(difficulty)?.abbreviation ?: difficulty,
        difficultyColor = SDVXColors.difficultyColor(difficulty),
        metrics = metrics
    )
}

fun DDRSongRecord.toShareCardEntry(): ShareCardEntry {
    val metrics = buildList {
        if (score != 0) add(ShareCardMetric(score.toString(), scoreGradientBrush))
        if (rank.isNotEmpty()) {
            add(ShareCardMetric(DDRRank.display(rank), SolidColor(DDRColors.rankColor(rank, darkTheme = true))))
        }
        if (clearKind.isNotEmpty()) {
            add(ShareCardMetric(
                DDRClearLamp.display(clearKind),
                SolidColor(DDRColors.clearColor(clearKind, darkTheme = true))
            ))
        }
    }
    return ShareCardEntry(
        title = title,
        lamp = lampBrush(clearKind.isEmpty(), DDRColors.clearColor(clearKind, darkTheme = true)),
        levelText = if (level > 0) level.toString() else "-",
        difficultyText = difficulty,
        difficultyColor = DDRColors.difficultyColor(difficulty),
        metrics = metrics
    )
}

fun PolarisChordSongRecord.toShareCardEntry(): ShareCardEntry {
    val clearType = PolarisChordClearType.fromValue(clearType)
    val metrics = buildList {
        if (achievementRate.isNotEmpty()) add(ShareCardMetric("$achievementRate%", scoreGradientBrush))
        val grade = PolarisChordGrade.fromValue(grade)
        if (grade != null && grade != PolarisChordGrade.NONE) {
            add(ShareCardMetric(
                this@toShareCardEntry.grade,
                PolarisChordColors.gradeBrush(this@toShareCardEntry.grade, darkTheme = true)
            ))
        }
        add(ShareCardMetric(
            clearType?.abbreviation ?: this@toShareCardEntry.clearType,
            SolidColor(PolarisChordColors.clearTypeColor(this@toShareCardEntry.clearType))
        ))
    }
    return ShareCardEntry(
        title = title,
        lamp = lampBrush(
            clearType == null || clearType == PolarisChordClearType.NO_PLAY,
            PolarisChordColors.clearTypeColor(this.clearType)
        ),
        levelText = level,
        difficultyText = difficulty,
        difficultyColor = PolarisChordColors.difficultyColor(difficulty),
        metrics = metrics
    )
}

private fun lampBrush(isEmpty: Boolean, color: Color): Brush =
    SolidColor(if (isEmpty) Color.Transparent else color)

fun IIDXProfile.toShareCardProfile(playType: IIDXPlayType): ShareCardProfile {
    val rank = (if (playType == IIDXPlayType.SINGLE) spRank else dpRank)?.takeIf { it.isNotEmpty() && it != "--" }
    val radar = if (playType == IIDXPlayType.SINGLE) spRadar else dpRadar
    return ShareCardProfile(
        playerName = djName,
        ratings = listOfNotNull(
            rank?.let { ShareCardRating(playType.displayName, it) },
            radar?.let { ShareCardRating("NOTES RADAR", String.format(Locale.ROOT, "%.2f", it.sum())) }
        )
    )
}

fun SDVXProfile.toShareCardProfile(): ShareCardProfile = ShareCardProfile(
    playerName = playerName?.replace("\n", " "),
    ratings = listOfNotNull(volforce?.takeIf { it.isNotEmpty() }?.let { ShareCardRating("VOLFORCE", it) })
)

fun DDRProfile.toShareCardProfile(style: DDRPlayStyle): ShareCardProfile = ShareCardProfile(
    playerName = dancerName,
    ratings = listOfNotNull(
        flareSkill[style]?.takeIf { it.isNotEmpty() }?.let { ShareCardRating("FLARE SKILL", it) }
    )
)

fun PolarisChordProfile.toShareCardProfile(): ShareCardProfile = ShareCardProfile(
    playerName = playerName,
    ratings = listOfNotNull(paSkill?.takeIf { it.isNotEmpty() }?.let { ShareCardRating("PA SKILL", it) })
)
