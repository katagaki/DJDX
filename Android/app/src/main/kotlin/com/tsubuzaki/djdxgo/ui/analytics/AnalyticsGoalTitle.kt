package com.tsubuzaki.djdxgo.ui.analytics

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.Game
import com.tsubuzaki.djdxgo.data.analytics.AnalyticsGoal
import com.tsubuzaki.djdxgo.data.analytics.AnalyticsGoalKind
import com.tsubuzaki.djdxgo.data.sdvx.SDVXClearType
import com.tsubuzaki.djdxgo.ui.common.IIDXClearTypeText
import com.tsubuzaki.djdxgo.ui.common.IIDXDJLevelText
import com.tsubuzaki.djdxgo.ui.common.OutlinedText
import com.tsubuzaki.djdxgo.ui.games.MetadataDivider
import com.tsubuzaki.djdxgo.ui.theme.DDRColors
import com.tsubuzaki.djdxgo.ui.theme.SDVXColors
import com.tsubuzaki.djdxgo.ui.theme.gameFont

@Composable
fun AnalyticsGoalTitle(goal: AnalyticsGoal, style: TextStyle, modifier: Modifier = Modifier) {
    val gameStyle = style.gameFont()
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (goal.kind == AnalyticsGoalKind.RATING) {
            Text(text = goal.title, style = gameStyle, fontWeight = FontWeight.Black, maxLines = 1)
        } else {
            Text(
                text = if (goal.level > 0) "LEVEL ${goal.level}" else stringResource(R.string.goals_level_all),
                style = gameStyle,
                fontWeight = FontWeight.Black,
                maxLines = 1
            )
            MetadataDivider()
            GoalThresholdText(goal, style)
        }
        goal.subtitle?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.labelSmall.gameFont(),
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1
            )
        }
    }
}

@Composable
private fun GoalThresholdText(goal: AnalyticsGoal, style: TextStyle) {
    val darkTheme = isSystemInDarkTheme()
    val game = goal.gameEnum
    val display = AnalyticsGoal.thresholdDisplay(goal.threshold, goal.kind, game)
    val gameStyle = style.gameFont()
    when {
        game == Game.IIDX_ARCADE && goal.kind == AnalyticsGoalKind.CLEAR_COUNT ->
            IIDXClearTypeText(goal.threshold, style)
        game == Game.IIDX_ARCADE && goal.kind == AnalyticsGoalKind.GRADE_COUNT ->
            IIDXDJLevelText(goal.threshold, style)
        game == Game.SOUND_VOLTEX && goal.kind == AnalyticsGoalKind.GRADE_COUNT ->
            OutlinedText(
                text = display,
                style = gameStyle,
                fontWeight = FontWeight.Black,
                fill = SDVXColors.gradeBrush,
                outline = SDVXColors.gradeOutlineColor,
                outlineWidth = 0.3.dp
            )
        game == Game.SOUND_VOLTEX && goal.kind == AnalyticsGoalKind.CLEAR_COUNT ->
            Text(
                text = SDVXClearType.fromValue(goal.threshold)?.abbreviation ?: display,
                style = gameStyle,
                fontWeight = FontWeight.Bold,
                color = SDVXColors.clearTypeColor(goal.threshold)
            )
        game == Game.DANCE_DANCE_REVOLUTION && goal.kind == AnalyticsGoalKind.GRADE_COUNT ->
            Text(
                text = display,
                style = gameStyle,
                fontWeight = FontWeight.Black,
                color = DDRColors.rankColor(goal.threshold, darkTheme)
            )
        game == Game.DANCE_DANCE_REVOLUTION && goal.kind == AnalyticsGoalKind.CLEAR_COUNT ->
            Text(
                text = display,
                style = gameStyle,
                fontWeight = FontWeight.Bold,
                color = DDRColors.clearColor(goal.threshold, darkTheme)
            )
        else -> Text(text = display, style = gameStyle, fontWeight = FontWeight.Bold)
    }
}
